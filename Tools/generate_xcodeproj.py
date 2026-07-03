#!/usr/bin/env python3
"""Generate WebsterDictionary.xcodeproj/project.pbxproj.

Programmatic generation keeps the ~hundred object IDs unique and consistent
(hand-editing pbxproj is where mistakes creep in). Re-run after adding or
removing source files:

    python3 Tools/generate_xcodeproj.py

You can also regenerate the whole project with XcodeGen (see project.yml).
"""

import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "WebsterDictionary"
IOS_TARGET = "WebsterDictionary"
WATCH_TARGET = "WebsterDictionary Watch App"
IOS_BUNDLE_ID = "com.laffan.WebsterDictionary"
WATCH_BUNDLE_ID = "com.laffan.WebsterDictionary.watchkitapp"

# Source files compiled into BOTH the iOS and watch targets.
SHARED_SWIFT = [
    "Sources/Shared/Models/DictionaryEntry.swift",
    "Sources/Shared/Models/Headword.swift",
    "Sources/Shared/Data/DictionaryDatabase.swift",
    "Sources/Shared/Data/DefinitionFormatter.swift",
    "Sources/Shared/Store/DictionaryStore.swift",
    "Sources/Shared/Store/RecentsStore.swift",
    "Sources/Shared/Views/ViewHelpers.swift",
    "Sources/Shared/Views/EntryRow.swift",
    "Sources/Shared/Views/DefinitionView.swift",
    "Sources/Shared/Views/FormattedDefinitionView.swift",
    "Sources/Shared/Views/SearchContent.swift",
    "Sources/Shared/Views/BrowseContent.swift",
    "Sources/Shared/Views/RandomContent.swift",
    "Sources/Shared/Views/RecentsContent.swift",
]
SHARED_RESOURCE = "Sources/Shared/Resources/dictionary.sqlite"

IOS_SWIFT = [
    "Sources/iOS/WebsterDictionaryApp.swift",
    "Sources/iOS/RootTabView.swift",
]
IOS_ASSETS = "Sources/iOS/Assets.xcassets"
IOS_PLIST = "Sources/iOS/Info.plist"

WATCH_SWIFT = [
    "Sources/Watch/WatchApp.swift",
    "Sources/Watch/WatchRootView.swift",
]
WATCH_ASSETS = "Sources/Watch/Assets.xcassets"
WATCH_PLIST = "Sources/Watch/Info.plist"

# ---------------------------------------------------------------------------
# ID allocation
# ---------------------------------------------------------------------------
_counter = [0]


def new_id():
    _counter[0] += 1
    return f"{_counter[0]:024X}"


def q(value):
    """Quote a value for the pbxproj format when needed."""
    s = str(value)
    if s == "":
        return '""'
    safe = all(c.isalnum() or c in "_./" for c in s)
    if safe:
        return s
    escaped = s.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def file_type(path):
    if path.endswith(".swift"):
        return "sourcecode.swift"
    if path.endswith(".plist"):
        return "text.plist.xml"
    if path.endswith(".xcassets"):
        return "folder.assetcatalog"
    if path.endswith(".sqlite"):
        return "file"
    return "text"


# ---------------------------------------------------------------------------
# Object model
# ---------------------------------------------------------------------------
build_files = []      # (id, comment, fileRef, settings_or_None)
file_refs = {}        # path -> id
product_refs = {}     # name -> id
groups = []           # (id, name, children_ids, is_main, path_or_none)
sources_phase = {}    # target -> (phase_id, [buildfile_ids])
resources_phase = {}
frameworks_phase = {}
embed_phase = {}      # target -> (phase_id, [buildfile_ids])
native_targets = []
configs = []          # (id, name, settings_dict)
config_lists = []     # (id, comment, [config_ids], default_name)
dependencies = []     # (dep_id, target_id, proxy_id)
proxies = []          # (proxy_id, target_id, target_name)


def ref_for(path):
    if path not in file_refs:
        file_refs[path] = new_id()
    return file_refs[path]


def add_build_file(path, settings=None):
    bf = new_id()
    build_files.append((bf, os.path.basename(path), ref_for(path), settings))
    return bf


def add_product(name, filetype):
    pid = new_id()
    product_refs[name] = pid
    return pid


# --- File references for all source files & assets ---
for p in SHARED_SWIFT + IOS_SWIFT + WATCH_SWIFT:
    ref_for(p)
ref_for(SHARED_RESOURCE)
ref_for(IOS_ASSETS)
ref_for(WATCH_ASSETS)
ref_for(IOS_PLIST)
ref_for(WATCH_PLIST)

ios_product_id = add_product(IOS_TARGET, "wrapper.application")
watch_product_id = add_product(WATCH_TARGET, "wrapper.application")

# --- Sources build phases ---
ios_source_bfs = [add_build_file(p) for p in SHARED_SWIFT + IOS_SWIFT]
watch_source_bfs = [add_build_file(p) for p in SHARED_SWIFT + WATCH_SWIFT]

# --- Resources build phases ---
ios_resource_bfs = [add_build_file(SHARED_RESOURCE), add_build_file(IOS_ASSETS)]
watch_resource_bfs = [add_build_file(SHARED_RESOURCE), add_build_file(WATCH_ASSETS)]

# --- Embed Watch Content (build file references the watch product) ---
embed_bf = new_id()
build_files.append(
    (embed_bf, f"{WATCH_TARGET}.app", watch_product_id,
     "{ATTRIBUTES = (RemoveHeadersOnCopy, ); }")
)

ios_sources_phase = new_id()
ios_resources_phase = new_id()
ios_frameworks_phase = new_id()
ios_embed_phase = new_id()
watch_sources_phase = new_id()
watch_resources_phase = new_id()
watch_frameworks_phase = new_id()

# --- Dependency: iOS app -> watch app ---
proxy_id = new_id()
dep_id = new_id()

# Top-level object ids, assigned up front so cross-references are unambiguous.
project_id = new_id()
ios_target_id = new_id()
watch_target_id = new_id()

# ---------------------------------------------------------------------------
# Groups (display only; file refs resolve via SOURCE_ROOT paths)
# ---------------------------------------------------------------------------
def make_group(name, child_ids, path=None):
    gid = new_id()
    groups.append((gid, name, child_ids, path))
    return gid


models_g = make_group("Models", [
    file_refs["Sources/Shared/Models/DictionaryEntry.swift"],
    file_refs["Sources/Shared/Models/Headword.swift"],
])
data_g = make_group("Data", [
    file_refs["Sources/Shared/Data/DictionaryDatabase.swift"],
    file_refs["Sources/Shared/Data/DefinitionFormatter.swift"],
])
store_g = make_group("Store", [
    file_refs["Sources/Shared/Store/DictionaryStore.swift"],
    file_refs["Sources/Shared/Store/RecentsStore.swift"],
])
views_g = make_group("Views", [
    file_refs["Sources/Shared/Views/ViewHelpers.swift"],
    file_refs["Sources/Shared/Views/EntryRow.swift"],
    file_refs["Sources/Shared/Views/DefinitionView.swift"],
    file_refs["Sources/Shared/Views/FormattedDefinitionView.swift"],
    file_refs["Sources/Shared/Views/SearchContent.swift"],
    file_refs["Sources/Shared/Views/BrowseContent.swift"],
    file_refs["Sources/Shared/Views/RandomContent.swift"],
    file_refs["Sources/Shared/Views/RecentsContent.swift"],
])
resources_g = make_group("Resources", [file_refs[SHARED_RESOURCE]])
shared_g = make_group("Shared", [models_g, data_g, store_g, views_g, resources_g])

ios_g = make_group("iOS", [
    file_refs["Sources/iOS/WebsterDictionaryApp.swift"],
    file_refs["Sources/iOS/RootTabView.swift"],
    file_refs[IOS_ASSETS],
    file_refs[IOS_PLIST],
])
watch_g = make_group("Watch", [
    file_refs["Sources/Watch/WatchApp.swift"],
    file_refs["Sources/Watch/WatchRootView.swift"],
    file_refs[WATCH_ASSETS],
    file_refs[WATCH_PLIST],
])
sources_g = make_group("Sources", [shared_g, ios_g, watch_g])
products_g = make_group("Products", [ios_product_id, watch_product_id])
main_g = make_group(None, [sources_g, products_g])

# ---------------------------------------------------------------------------
# Build settings
# ---------------------------------------------------------------------------
PROJECT_COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "SWIFT_VERSION": "5.0",
    "MARKETING_VERSION": "1.0",
    "CURRENT_PROJECT_VERSION": "1",
}
PROJECT_DEBUG = {
    **PROJECT_COMMON,
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": '("DEBUG=1", "$(inherited)", )',
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
}
PROJECT_RELEASE = {
    **PROJECT_COMMON,
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "COPY_PHASE_STRIP": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": "-O",
}

IOS_COMMON = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": IOS_PLIST,
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LD_RUNPATH_SEARCH_PATHS": '("$(inherited)", "@executable_path/Frameworks", )',
    "MARKETING_VERSION": "1.0",
    "OTHER_LDFLAGS": "-lsqlite3",
    "PRODUCT_BUNDLE_IDENTIFIER": IOS_BUNDLE_ID,
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SDKROOT": "iphoneos",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "TARGETED_DEVICE_FAMILY": "1,2",
}
WATCH_COMMON = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": WATCH_PLIST,
    "LD_RUNPATH_SEARCH_PATHS": '("$(inherited)", "@executable_path/Frameworks", )',
    "MARKETING_VERSION": "1.0",
    "OTHER_LDFLAGS": "-lsqlite3",
    "PRODUCT_BUNDLE_IDENTIFIER": WATCH_BUNDLE_ID,
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SDKROOT": "watchos",
    "SKIP_INSTALL": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "TARGETED_DEVICE_FAMILY": "4",
    "WATCHOS_DEPLOYMENT_TARGET": "10.0",
}


def make_config_list(debug_settings, release_settings):
    debug_id = new_id()
    release_id = new_id()
    configs.append((debug_id, "Debug", debug_settings))
    configs.append((release_id, "Release", release_settings))
    list_id = new_id()
    config_lists.append((list_id, [debug_id, release_id]))
    return list_id


project_config_list = make_config_list(PROJECT_DEBUG, PROJECT_RELEASE)
ios_config_list = make_config_list(IOS_COMMON, IOS_COMMON)
watch_config_list = make_config_list(WATCH_COMMON, WATCH_COMMON)

# ---------------------------------------------------------------------------
# Emit
# ---------------------------------------------------------------------------
def settings_value(value):
    """Quote a build-setting value, leaving list/dict literals untouched."""
    s = str(value)
    if s[:1] in ("(", "{"):
        return s  # already a pbxproj list/dict literal
    return q(s)


def settings_block(settings, indent):
    pad = "\t" * indent
    lines = []
    for key in sorted(settings):
        lines.append(f"{pad}{q(key)} = {settings_value(settings[key])};")
    return "\n".join(lines)


out = []
out.append("// !$*UTF8*$!")
out.append("{")
out.append("\tarchiveVersion = 1;")
out.append("\tclasses = {")
out.append("\t};")
out.append("\tobjectVersion = 56;")
out.append("\tobjects = {")

# PBXBuildFile
out.append("\n/* Begin PBXBuildFile section */")
for bf, comment, ref, settings in build_files:
    ref_comment = comment
    settings_str = f" settings = {settings};" if settings else ""
    # Distinguish "in Sources" vs "in Resources"/"in Embed" comment loosely.
    out.append(
        f"\t\t{bf} /* {comment} */ = {{isa = PBXBuildFile; fileRef = {ref} /* {ref_comment} */;{settings_str} }};"
    )
out.append("/* End PBXBuildFile section */")

# PBXContainerItemProxy
out.append("\n/* Begin PBXContainerItemProxy section */")
out.append(
    f"\t\t{proxy_id} /* PBXContainerItemProxy */ = {{\n"
    f"\t\t\tisa = PBXContainerItemProxy;\n"
    f"\t\t\tcontainerPortal = {project_id} /* Project object */;\n"
    f"\t\t\tproxyType = 1;\n"
    f"\t\t\tremoteGlobalIDString = {watch_target_id};\n"
    f"\t\t\tremoteInfo = {q(WATCH_TARGET)};\n"
    f"\t\t}};"
)
out.append("/* End PBXContainerItemProxy section */")

# PBXCopyFilesBuildPhase (Embed Watch Content)
out.append("\n/* Begin PBXCopyFilesBuildPhase section */")
out.append(
    f"\t\t{ios_embed_phase} /* Embed Watch Content */ = {{\n"
    f"\t\t\tisa = PBXCopyFilesBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tdstPath = \"$(CONTENTS_FOLDER_PATH)/Watch\";\n"
    f"\t\t\tdstSubfolderSpec = 16;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t\t{embed_bf} /* {WATCH_TARGET}.app in Embed Watch Content */,\n"
    f"\t\t\t);\n"
    f"\t\t\tname = \"Embed Watch Content\";\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};"
)
out.append("/* End PBXCopyFilesBuildPhase section */")

# PBXFileReference
out.append("\n/* Begin PBXFileReference section */")
for path, rid in file_refs.items():
    name = os.path.basename(path)
    out.append(
        f"\t\t{rid} /* {name} */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = {file_type(path)}; "
        f"path = {q(path)}; sourceTree = SOURCE_ROOT; }};"
    )
for name, rid in product_refs.items():
    out.append(
        f"\t\t{rid} /* {name}.app */ = {{isa = PBXFileReference; "
        f"explicitFileType = wrapper.application; includeInIndex = 0; "
        f"path = {q(name + '.app')}; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
out.append("/* End PBXFileReference section */")

# PBXFrameworksBuildPhase (empty; SQLite linked via -lsqlite3)
out.append("\n/* Begin PBXFrameworksBuildPhase section */")
for pid in (ios_frameworks_phase, watch_frameworks_phase):
    out.append(
        f"\t\t{pid} /* Frameworks */ = {{\n"
        f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
out.append("/* End PBXFrameworksBuildPhase section */")

# PBXGroup
out.append("\n/* Begin PBXGroup section */")
for gid, name, child_ids, path in groups:
    child_lines = "\n".join(f"\t\t\t\t{c} /* child */," for c in child_ids)
    name_line = f"\t\t\tname = {q(name)};\n" if name else ""
    out.append(
        f"\t\t{gid} /* {name or 'Main'} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n{child_lines}\n\t\t\t);\n"
        f"{name_line}"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )
out.append("/* End PBXGroup section */")

# PBXNativeTarget
out.append("\n/* Begin PBXNativeTarget section */")
out.append(
    f"\t\t{ios_target_id} /* {IOS_TARGET} */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {ios_config_list} /* Build configuration list for PBXNativeTarget \"{IOS_TARGET}\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{ios_sources_phase} /* Sources */,\n"
    f"\t\t\t\t{ios_frameworks_phase} /* Frameworks */,\n"
    f"\t\t\t\t{ios_resources_phase} /* Resources */,\n"
    f"\t\t\t\t{ios_embed_phase} /* Embed Watch Content */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n\t\t\t);\n"
    f"\t\t\tdependencies = (\n\t\t\t\t{dep_id} /* PBXTargetDependency */,\n\t\t\t);\n"
    f"\t\t\tname = {q(IOS_TARGET)};\n"
    f"\t\t\tproductName = {q(IOS_TARGET)};\n"
    f"\t\t\tproductReference = {ios_product_id} /* {IOS_TARGET}.app */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.application\";\n"
    f"\t\t}};"
)
out.append(
    f"\t\t{watch_target_id} /* {WATCH_TARGET} */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {watch_config_list} /* Build configuration list for PBXNativeTarget \"{WATCH_TARGET}\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{watch_sources_phase} /* Sources */,\n"
    f"\t\t\t\t{watch_frameworks_phase} /* Frameworks */,\n"
    f"\t\t\t\t{watch_resources_phase} /* Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n\t\t\t);\n"
    f"\t\t\tdependencies = (\n\t\t\t);\n"
    f"\t\t\tname = {q(WATCH_TARGET)};\n"
    f"\t\t\tproductName = {q(WATCH_TARGET)};\n"
    f"\t\t\tproductReference = {watch_product_id} /* {WATCH_TARGET}.app */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.application\";\n"
    f"\t\t}};"
)
out.append("/* End PBXNativeTarget section */")

# PBXProject
out.append("\n/* Begin PBXProject section */")
out.append(
    f"\t\t{project_id} /* Project object */ = {{\n"
    f"\t\t\tisa = PBXProject;\n"
    f"\t\t\tattributes = {{\n"
    f"\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
    f"\t\t\t\tLastSwiftUpdateCheck = 1540;\n"
    f"\t\t\t\tLastUpgradeCheck = 1540;\n"
    f"\t\t\t\tTargetAttributes = {{\n"
    f"\t\t\t\t\t{ios_target_id} = {{ CreatedOnToolsVersion = 15.4; }};\n"
    f"\t\t\t\t\t{watch_target_id} = {{ CreatedOnToolsVersion = 15.4; }};\n"
    f"\t\t\t\t}};\n"
    f"\t\t\t}};\n"
    f"\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject */;\n"
    f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
    f"\t\t\tdevelopmentRegion = en;\n"
    f"\t\t\thasScannedForEncodings = 0;\n"
    f"\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n"
    f"\t\t\tmainGroup = {main_g};\n"
    f"\t\t\tproductRefGroup = {products_g} /* Products */;\n"
    f"\t\t\tprojectDirPath = \"\";\n"
    f"\t\t\tprojectRoot = \"\";\n"
    f"\t\t\ttargets = (\n"
    f"\t\t\t\t{ios_target_id} /* {IOS_TARGET} */,\n"
    f"\t\t\t\t{watch_target_id} /* {WATCH_TARGET} */,\n"
    f"\t\t\t);\n"
    f"\t\t}};"
)
out.append("/* End PBXProject section */")

# PBXResourcesBuildPhase
out.append("\n/* Begin PBXResourcesBuildPhase section */")
for pid, bfs in ((ios_resources_phase, ios_resource_bfs), (watch_resources_phase, watch_resource_bfs)):
    files = "\n".join(f"\t\t\t\t{b} /* in Resources */," for b in bfs)
    out.append(
        f"\t\t{pid} /* Resources */ = {{\n"
        f"\t\t\tisa = PBXResourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n{files}\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
out.append("/* End PBXResourcesBuildPhase section */")

# PBXSourcesBuildPhase
out.append("\n/* Begin PBXSourcesBuildPhase section */")
for pid, bfs in ((ios_sources_phase, ios_source_bfs), (watch_sources_phase, watch_source_bfs)):
    files = "\n".join(f"\t\t\t\t{b} /* in Sources */," for b in bfs)
    out.append(
        f"\t\t{pid} /* Sources */ = {{\n"
        f"\t\t\tisa = PBXSourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n{files}\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
out.append("/* End PBXSourcesBuildPhase section */")

# PBXTargetDependency
out.append("\n/* Begin PBXTargetDependency section */")
out.append(
    f"\t\t{dep_id} /* PBXTargetDependency */ = {{\n"
    f"\t\t\tisa = PBXTargetDependency;\n"
    f"\t\t\ttarget = {watch_target_id} /* {WATCH_TARGET} */;\n"
    f"\t\t\ttargetProxy = {proxy_id} /* PBXContainerItemProxy */;\n"
    f"\t\t}};"
)
out.append("/* End PBXTargetDependency section */")

# XCBuildConfiguration
out.append("\n/* Begin XCBuildConfiguration section */")
for cid, cname, settings in configs:
    out.append(
        f"\t\t{cid} /* {cname} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n{settings_block(settings, 4)}\n\t\t\t}};\n"
        f"\t\t\tname = {cname};\n"
        f"\t\t}};"
    )
out.append("/* End XCBuildConfiguration section */")

# XCConfigurationList
out.append("\n/* Begin XCConfigurationList section */")
for lid, cfg_ids in config_lists:
    cfgs = "\n".join(f"\t\t\t\t{c} /* config */," for c in cfg_ids)
    out.append(
        f"\t\t{lid} /* Build configuration list */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n{cfgs}\n\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};"
    )
out.append("/* End XCConfigurationList section */")

out.append("\t};")
out.append(f"\trootObject = {project_id} /* Project object */;")
out.append("}")

# ---------------------------------------------------------------------------
# Write
# ---------------------------------------------------------------------------
proj_dir = os.path.join(REPO, f"{PROJECT}.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)
with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
    f.write("\n".join(out) + "\n")

print(f"Wrote {proj_dir}/project.pbxproj")
