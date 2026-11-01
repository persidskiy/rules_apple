# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""An aspect that collects the dependencies tagged `LINKABLE_MORE_THAN_ONCE`."""

LINKABLE_MORE_THAN_ONCE = "LINKABLE_MORE_THAN_ONCE"

LinkableMoreThanOnceInfo = provider(
    doc = """\
A provider that lists the targets in a dependency graph that are tagged
`LINKABLE_MORE_THAN_ONCE`.
""",
    fields = {
        "labels": "A `depset` of `Label`s of the targets tagged `LINKABLE_MORE_THAN_ONCE`.",
    },
)

_LINKABLE_MORE_THAN_ONCE_ASPECT_ATTRS = [
    "deps",
    "implementation_deps",
    "private_deps",
]

def _linkable_more_than_once_aspect_impl(target, aspect_ctx):
    direct = []
    if LINKABLE_MORE_THAN_ONCE in getattr(aspect_ctx.rule.attr, "tags", []):
        direct.append(target.label)

    transitive = []
    for attribute in _LINKABLE_MORE_THAN_ONCE_ASPECT_ATTRS:
        deps = getattr(aspect_ctx.rule.attr, attribute, None)
        if type(deps) != "list":
            continue
        for dep in deps:
            if LinkableMoreThanOnceInfo in dep:
                transitive.append(dep[LinkableMoreThanOnceInfo].labels)

    if not direct and not transitive:
        return []

    return [LinkableMoreThanOnceInfo(labels = depset(direct, transitive = transitive))]

linkable_more_than_once_aspect = aspect(
    attr_aspects = _LINKABLE_MORE_THAN_ONCE_ASPECT_ATTRS,
    doc = """\
Collects the targets tagged `LINKABLE_MORE_THAN_ONCE` in a dependency tree.

Libraries that are already linked into a dynamic framework listed in `frameworks` are normally
removed from the binary that depends on the framework. Tagging a library with
`LINKABLE_MORE_THAN_ONCE`, as with `cc_shared_library` in rules_cc, keeps it in the binary's link as
well, so that each image gets its own copy. This is required when the framework does not export the
library's symbols, e.g. when the library is built with `-fvisibility=hidden`.
""",
    implementation = _linkable_more_than_once_aspect_impl,
)
