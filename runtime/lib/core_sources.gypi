# Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Sources visible via default library.

{
  'sources': [
    'core_patch.dart',
    # The above file needs to be first as it imports required libraries.
    'array.cc',
    'array.dart',
    'array_patch.dart',
    'bigint.dart',
    'bool.cc',
    'bool_patch.dart',
    'date.cc',
    'date_patch.dart',
    'double.cc',
    'double.dart',
    'double_patch.dart',
    'errors.cc',
    'errors_patch.dart',
    'expando_patch.dart',
    'function.cc',
    'function.dart',
    'function_patch.dart',
    'growable_array.cc',
    'growable_array.dart',
    'identical.cc',
    'identical_patch.dart',
    'immutable_map.dart',
    'integers.cc',
    'integers.dart',
    'integers_patch.dart',
    'invocation_mirror.h',
    'invocation_mirror_patch.dart',
    'lib_prefix.dart',
    'map_patch.dart',
    'null_patch.dart',
    'object.cc',
    'object_patch.dart',
    'regexp.cc',
    'regexp_patch.dart',
    'stacktrace.cc',
    'stacktrace.dart',
    'stacktrace.h',
    'stopwatch.cc',
    'stopwatch_patch.dart',
    'string.cc',
    'string_buffer_patch.dart',
    'string_patch.dart',
    'type_patch.dart',
    'uri.cc',
    'uri_patch.dart',
    'weak_property.cc',
    'weak_property.dart',
  ],
}
