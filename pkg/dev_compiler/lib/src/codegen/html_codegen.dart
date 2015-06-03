// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dev_compiler.src.codegen.html_codegen;

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:logging/logging.dart' show Logger;
import 'package:path/path.dart' as path;

import 'package:dev_compiler/src/dependency_graph.dart';
import 'package:dev_compiler/src/options.dart';
import 'package:dev_compiler/src/utils.dart' show colorOf, resourceOutputPath;

import 'js_codegen.dart' show jsLibraryName, jsOutputPath;

/// Emits an entry point HTML file corresponding to [inputFile] that can load
/// the code generated by the dev compiler.
///
/// This internally transforms the given HTML [document]. When compiling to
/// JavaScript, we remove any Dart script tags, add new script tags to load our
/// runtime and the compiled code, and to execute the main method of the
/// application. When compiling to Dart, we ensure that the document contains a
/// single Dart script tag, but otherwise emit the original document
/// unmodified.
String generateEntryHtml(HtmlSourceNode root, CompilerOptions options) {
  var document = root.document.clone(true);
  var scripts = document.querySelectorAll('script[type="application/dart"]');
  if (scripts.isEmpty) {
    _log.severe('No <script type="application/dart"> found in ${root.uri}');
    return null;
  }
  scripts.skip(1).forEach((s) {
    // TODO(sigmund): allow more than one Dart script tags?
    _log.warning(s.sourceSpan.message(
        'unexpected script. Only one Dart script tag allowed '
        '(see https://github.com/dart-lang/dart-dev-compiler/issues/53).',
        color: options.useColors ? colorOf('warning') : false));
    s.remove();
  });

  var libraries = [];
  var resources = new Set();
  visitInPostOrder(root, (n) {
    if (n is DartSourceNode) libraries.add(n);
    if (n is ResourceSourceNode) resources.add(n);
  }, includeParts: false);

  root.htmlResourceNodes.forEach((element, resource) {
    // Make sure we don't try and add this node again.
    resources.remove(resource);

    var resourcePath = resourceOutputPath(resource.uri, root.uri);
    if (resource.cachingHash != null) {
      resourcePath = _addHash(resourcePath, resource.cachingHash);
    }
    var attrs = element.attributes;
    if (attrs.containsKey('href')) {
      attrs['href'] = resourcePath;
    } else if (attrs.containsKey('src')) {
      attrs['src'] = resourcePath;
    }
  });

  var fragment = new DocumentFragment();
  for (var resource in resources) {
    var resourcePath = resourceOutputPath(resource.uri, root.uri);
    var ext = path.extension(resourcePath);
    if (resource.cachingHash != null) {
      resourcePath = _addHash(resourcePath, resource.cachingHash);
    }
    if (ext == '.js') {
      fragment.nodes.add(_libraryInclude(resourcePath));
    } else if (ext == '.css') {
      var stylesheetLink = '<link rel="stylesheet" href="$resourcePath">\n';
      fragment.nodes.add(parseFragment(stylesheetLink));
    }
  }

  String mainLibraryName;
  for (var lib in libraries) {
    var info = lib.info;
    if (info == null) continue;
    if (info.isEntry) mainLibraryName = jsLibraryName(info.library);
    var jsPath = jsOutputPath(info, root.uri);
    if (lib.cachingHash != null) {
      jsPath = _addHash(jsPath, lib.cachingHash);
    }
    fragment.nodes.add(_libraryInclude(jsPath));
  }
  fragment.nodes.add(_invokeMain(mainLibraryName));
  scripts[0].replaceWith(fragment);
  return '${document.outerHtml}\n';
}

/// A script tag that loads the .js code for a compiled library.
Node _libraryInclude(String jsUrl) =>
    parseFragment('<script src="$jsUrl"></script>\n');

/// A script tag that invokes the main function on the entry point library.
Node _invokeMain(String mainLibraryName) {
  var code = mainLibraryName == null
      ? 'console.error("dev_compiler error: main was not generated");'
      // TODO(vsm): Can we simplify this?
      // See: https://github.com/dart-lang/dev_compiler/issues/164
      : '_isolate_helper.startRootIsolate($mainLibraryName.main, []);';
  return parseFragment('<script>$code</script>\n');
}

/// Convert the outputPath to include the hash in it. This function is the
/// reverse of what the server does to determine whether a request needs to have
/// cache headers added to it.
_addHash(String outPath, String hash) {
  // (the ____ prefix makes it look better in the web inspector)
  return '$outPath?____cached=$hash';
}

final _log = new Logger('dev_compiler.src.codegen.html_codegen');
