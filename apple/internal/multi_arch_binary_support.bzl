# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License(**kwargs): Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing(**kwargs): software
# distributed under the License is distributed on an "AS IS" BASIS(**kwargs):
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND(**kwargs): either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Support utility for creating multi-arch Apple binaries."""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("//apple/internal:compilation_support.bzl", "compilation_support")

visibility([
    "//apple/...",
])

def _build_avoid_library_set(avoid_dep_linking_contexts):
    avoid_library_set = dict()

    for linking_context in avoid_dep_linking_contexts:
        for linker_input in linking_context.linker_inputs.to_list():
            for library_to_link in linker_input.libraries:
                library_artifact = compilation_support.get_static_library_for_linking(library_to_link)
                if library_artifact:
                    avoid_library_set[library_artifact.short_path] = True

    return avoid_library_set

def subtract_linking_contexts(
        owner,
        linking_contexts,
        avoid_dep_linking_contexts,
        linkable_more_than_once_labels = depset()):
    """Subtracts the libraries in avoid_dep_linking_contexts from linking_contexts.

    Args:
      owner: The label of the target currently being analyzed.
      linking_contexts: An iterable of CcLinkingContext objects.
      avoid_dep_linking_contexts: An iterable of CcLinkingContext objects.
      linkable_more_than_once_labels: A depset of Labels of the targets whose libraries are kept
        even if they are also in avoid_dep_linking_contexts.

    Returns:
      A CcLinkingContext object.
    """
    libraries = []
    user_link_flags = []
    additional_inputs = []
    linkstamps = []
    avoid_library_set = _build_avoid_library_set(avoid_dep_linking_contexts)
    linkable_more_than_once_set = {
        label: True
        for label in linkable_more_than_once_labels.to_list()
    }
    kept_avoided_library_set = dict()
    linker_inputs_seen = dict()

    for linking_context in linking_contexts:
        for linker_input in linking_context.linker_inputs.to_list():
            if linker_input in linker_inputs_seen:
                continue

            linker_inputs_seen[linker_input] = True

            for library_to_link in linker_input.libraries:
                library_artifact = compilation_support.get_library_for_linking(library_to_link)
                short_path = library_artifact.short_path

                if short_path in avoid_library_set:
                    # The avoided dependency may have been built in another configuration, so
                    # its copy of the library would not be deduplicated by linker_inputs_seen.
                    if (linker_input.owner not in linkable_more_than_once_set or
                        short_path in kept_avoided_library_set):
                        continue
                    kept_avoided_library_set[short_path] = True

                libraries.append(library_to_link)

            user_link_flags.extend(linker_input.user_link_flags)
            additional_inputs.extend(linker_input.additional_inputs)
            linkstamps.extend(linker_input.linkstamps)

    return cc_common.create_linking_context(
        linker_inputs = depset([
            cc_common.create_linker_input(
                owner = owner,
                libraries = depset(libraries, order = "topological"),
                user_link_flags = user_link_flags,
                additional_inputs = depset(additional_inputs),
                linkstamps = depset(linkstamps),
            ),
        ]),
    )
