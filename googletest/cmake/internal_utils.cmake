# Defines functions and macros useful for building Google Test and
# Google Mock.
#
# Note:
#
# - This file will be run twice when building Google Mock (once via
#   Google Test's CMakeLists.txt, and once via Google Mock's).
#   Therefore it shouldn't have any side effects other than defining
#   the functions and macros.
#
# - The functions/macros defined in this file may depend on Google
#   Test and Google Mock's option() definitions, and thus must be
#   called *after* the options have been defined.

# Tweaks CMake's default compiler/linker settings to suit Google Test's needs.
#
# This must be a macro(), as inside a function string() can only
# update variables in the function scope.
macro(fix_default_compiler_settings_)
  if (MSVC)
    # For MSVC, CMake sets certain flags to defaults we want to override.
    # This replacement code is taken from sample in the CMake Wiki at
    # http://www.cmake.org/Wiki/CMake_FAQ#Dynamic_Replace.
    foreach (flag_var
             CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE
             CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO)
      if (NOT BUILD_SHARED_LIBS AND NOT gtest_force_shared_crt)
        # When Google Test is built as a shared library, it should also use
        # shared runtime libraries.  Otherwise, it may end up with multiple
        # copies of runtime library data in different modules, resulting in
        # hard-to-find crashes. When it is built as a static library, it is
        # preferable to use CRT as static libraries, as we don't have to rely
        # on CRT DLLs being available. CMake always defaults to using shared
        # CRT libraries, so we override that default here.
        string(REPLACE "/MD" "-MT" ${flag_var} "${${flag_var}}")
      endif()

      # We prefer more strict warning checking for building Google Test.
      # Replaces /W3 with /W4 in defaults.
      string(REPLACE "/W3" "/W4" ${flag_var} "${${flag_var}}")
    endforeach()
  endif()
endmacro()

# Defines the compiler/linker flags used to build Google Test and
# Google Mock.  You can tweak these definitions to suit your need.  A
# variable's value is empty before it's explicitly assigned to.
macro(config_compiler_and_linker)
  # Note: pthreads on MinGW is not supported, even if available
  # instead, we use windows threading primitives
  unset(GTEST_HAS_PTHREAD)
  if (NOT gtest_disable_pthreads AND NOT MINGW)
    # Defines CMAKE_USE_PTHREADS_INIT and CMAKE_THREAD_LIBS_INIT.
    if(NOT RASPBERRY_PI)
      set(THREADS_PREFER_PTHREAD_FLAG ON)
    endif()
    find_package(Threads)
    if (CMAKE_USE_PTHREADS_INIT)
      set(GTEST_HAS_PTHREAD ON)
    endif()
  endif()

  fix_default_compiler_settings_()
  if (MSVC)
    # Newlines inside flags variables break CMake's NMake generator.
    # TODO(vladl@google.com): Add -RTCs and -RTCu to debug builds.
    set(cxx_base_flags "-GS -W4 -WX -wd4251 -wd4275 -nologo -J -Zi")
    if (MSVC_VERSION LESS 1400)  # 1400 is Visual Studio 2005
      # Suppress spurious warnings MSVC 7.1 sometimes issues.
      # Forcing value to bool.
      set(cxx_base_flags "${cxx_base_flags} -wd4800")
      # Copy constructor and assignment operator could not be generated.
      set(cxx_base_flags "${cxx_base_flags} -wd4511 -wd4512")
      # Compatibility warnings not applicable to Google Test.
      # Resolved overload was found by argument-dependent lookup.
      set(cxx_base_flags "${cxx_base_flags} -wd4675")
    endif()
    if (MSVC_VERSION LESS 1500)  # 1500 is Visual Studio 2008
      # Conditional expression is constant.
      # When compiling with /W4, we get several instances of C4127
      # (Conditional expression is constant). In our code, we disable that
      # warning on a case-by-case basis. However, on Visual Studio 2005,
      # the warning fires on std::list. Therefore on that compiler and earlier,
      # we disable the warning project-wide.
      set(cxx_base_flags "${cxx_base_flags} -wd4127")
    endif()
    if (NOT (MSVC_VERSION LESS 1700))  # 1700 is Visual Studio 2012.
      # Suppress "unreachable code" warning on VS 2012 and later.
      # http://stackoverflow.com/questions/3232669 explains the issue.
      set(cxx_base_flags "${cxx_base_flags} -wd4702")
    endif()

    set(cxx_base_flags "${cxx_base_flags} -D_UNICODE -DUNICODE -DWIN32 -D_WIN32")
    set(cxx_base_flags "${cxx_base_flags} -DSTRICT -DWIN32_LEAN_AND_MEAN")
    set(cxx_exception_flags "-EHsc -D_HAS_EXCEPTIONS=1")
    set(cxx_no_exception_flags "-D_HAS_EXCEPTIONS=0")
    set(cxx_no_rtti_flags "-GR-")
  elseif (CMAKE_COMPILER_IS_GNUCXX)
    set(cxx_base_flags "-Wall -Wshadow -Werror")
    set(cxx_exception_flags "-fexceptions")
    set(cxx_no_exception_flags "-fno-exceptions")
    # Until version 4.3.2, GCC doesn't define a macro to indicate
    # whether RTTI is enabled.  Therefore we define GTEST_HAS_RTTI
    # explicitly.
    set(cxx_no_rtti_flags "-fno-rtti -DGTEST_HAS_RTTI=0")
    set(cxx_strict_flags
      "-Wextra -Wno-unused-parameter -Wno-missing-field-initializers")
  elseif (CMAKE_CXX_COMPILER_ID STREQUAL "SunPro")
    set(cxx_exception_flags "-features=except")
    # Sun Pro doesn't provide macros to indicate whether exceptions and
    # RTTI are enabled, so we define GTEST_HAS_* explicitly.
    set(cxx_no_exception_flags "-features=no%except -DGTEST_HAS_EXCEPTIONS=0")
    set(cxx_no_rtti_flags "-features=no%rtti -DGTEST_HAS_RTTI=0")
  elseif (CMAKE_CXX_COMPILER_ID STREQUAL "VisualAge" OR
      CMAKE_CXX_COMPILER_ID STREQUAL "XL")
    # CMake 2.8 changes Visual Age's compiler ID to "XL".
    set(cxx_exception_flags "-qeh")
    set(cxx_no_exception_flags "-qnoeh")
    # Until version 9.0, Visual Age doesn't define a macro to indicate
    # whether RTTI is enabled.  Therefore we define GTEST_HAS_RTTI
    # explicitly.
    set(cxx_no_rtti_flags "-qnortti -DGTEST_HAS_RTTI=0")
  elseif (CMAKE_CXX_COMPILER_ID STREQUAL "HP")
    set(cxx_base_flags "-AA -mt")
    set(cxx_exception_flags "-DGTEST_HAS_EXCEPTIONS=1")
    set(cxx_no_exception_flags "+noeh -DGTEST_HAS_EXCEPTIONS=0")
    # RTTI can not be disabled in HP aCC compiler.
    set(cxx_no_rtti_flags "")
  endif()

  # The pthreads library is available and allowed?
  if (DEFINED GTEST_HAS_PTHREAD)
    set(GTEST_HAS_PTHREAD_MACRO "-DGTEST_HAS_PTHREAD=1")
  else()
    set(GTEST_HAS_PTHREAD_MACRO "-DGTEST_HAS_PTHREAD=0")
  endif()
  set(cxx_base_flags "${cxx_base_flags} ${GTEST_HAS_PTHREAD_MACRO}")

  # For building gtest's own tests and samples.
  set(cxx_exception "${CMAKE_CXX_FLAGS} ${cxx_base_flags} ${cxx_exception_flags}")
  set(cxx_no_exception
    "${CMAKE_CXX_FLAGS} ${cxx_base_flags} ${cxx_no_exception_flags}")
  set(cxx_default "${cxx_exception}")
  set(cxx_no_rtti "${cxx_default} ${cxx_no_rtti_flags}")
  set(cxx_use_own_tuple "${cxx_default} -DGTEST_USE_OWN_TR1_TUPLE=1")

  # For building the gtest libraries.
  set(cxx_strict "${cxx_default} ${cxx_strict_flags}")
endmacro()

# Defines the gtest & gtest_main libraries.  User tests should link
# with one of them.
function(cxx_library_with_type name type cxx_flags)
  # type can be either STATIC or SHARED to denote a static or shared library.
  # ARGN refers to additional arguments after 'cxx_flags'.
  add_library(${name} ${type} ${ARGN})
  set_target_properties(${name}
    PROPERTIES
    COMPILE_FLAGS "${cxx_flags}")
  if (BUILD_SHARED_LIBS OR type STREQUAL "SHARED")
    set_target_properties(${name}
      PROPERTIES
      COMPILE_DEFINITIONS "GTEST_CREATE_SHARED_LIBRARY=1")
  endif()
  if (DEFINED GTEST_HAS_PTHREAD)
    target_link_libraries(${name} ${CMAKE_THREAD_LIBS_INIT})
  endif()
endfunction()

########################################################################
#
# Helper functions for creating build targets.

function(cxx_shared_library name cxx_flags)
  cxx_library_with_type(${name} SHARED "${cxx_flags}" ${ARGN})
endfunction()

function(cxx_library name cxx_flags)
  cxx_library_with_type(${name} "" "${cxx_flags}" ${ARGN})
endfunction()

# cxx_executable_with_flags(name cxx_flags libs srcs...)
#
# creates a named C++ executable that depends on the given libraries and
# is built from the given source files with the given compiler flags.
function(cxx_executable_with_flags name cxx_flags libs)
  add_executable(${name} ${ARGN})
  if (MSVC AND (NOT (MSVC_VERSION LESS 1700)))  # 1700 is Visual Studio 2012.
    # BigObj required for tests.
    set(cxx_flags "${cxx_flags} -bigobj")
  endif()
  if (cxx_flags)
    set_target_properties(${name}
      PROPERTIES
      COMPILE_FLAGS "${cxx_flags}")
  endif()
  if (BUILD_SHARED_LIBS)
    set_target_properties(${name}
      PROPERTIES
      COMPILE_DEFINITIONS "GTEST_LINKED_AS_SHARED_LIBRARY=1")
  endif()
  # To support mixing linking in static and dynamic libraries, link each
  # library in with an extra call to target_link_libraries.
  foreach (lib "${libs}")
    target_link_libraries(${name} ${lib})
  endforeach()
endfunction()

# cxx_executable(name dir lib srcs...)
#
# creates a named target that depends on the given libs and is built
# from the given source files.  dir/name.cc is implicitly included in
# the source file list.
function(cxx_executable name dir libs)
  cxx_executable_with_flags(
    ${name} "${cxx_default}" "${libs}" "${dir}/${name}.cc" ${ARGN})
endfunction()

# Sets PYTHONINTERP_FOUND and PYTHON_EXECUTABLE.
find_package(PythonInterp)

# cxx_test_with_flags(name cxx_flags libs srcs...)
#
# creates a named C++ test that depends on the given libs and is built
# from the given source files with the given compiler flags.
function(cxx_test_with_flags name cxx_flags libs)
  cxx_executable_with_flags(${name} "${cxx_flags}" "${libs}" ${ARGN})
  add_test(${name} ${name})
endfunction()

# cxx_test(name libs srcs...)
#
# creates a named test target that depends on the given libs and is
# built from the given source files.  Unlike cxx_test_with_flags,
# test/name.cc is already implicitly included in the source file list.
function(cxx_test name libs)
  cxx_test_with_flags("${name}" "${cxx_default}" "${libs}"
    "test/${name}.cc" ${ARGN})
endfunction()

# py_test(name)
#
# creates a Python test with the given name whose main module is in
# test/name.py.  It does nothing if Python is not installed.
function(py_test name)
  if (PYTHONINTERP_FOUND)
    if (${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION} GREATER 3.1)
      if (CMAKE_CONFIGURATION_TYPES)
	# Multi-configuration build generators as for Visual Studio save
	# output in a subdirectory of CMAKE_CURRENT_BINARY_DIR (Debug,
	# Release etc.), so we have to provide it here.
        add_test(
          NAME ${name}
          COMMAND ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/test/${name}.py
              --build_dir=${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>)
      else (CMAKE_CONFIGURATION_TYPES)
	# Single-configuration build generators like Makefile generators
	# don't have subdirs below CMAKE_CURRENT_BINARY_DIR.
        add_test(
          NAME ${name}
          COMMAND ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/test/${name}.py
              --build_dir=${CMAKE_CURRENT_BINARY_DIR})
      endif (CMAKE_CONFIGURATION_TYPES)
    else (${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION} GREATER 3.1)
      # ${CMAKE_CURRENT_BINARY_DIR} is known at configuration time, so we can
      # directly bind it from cmake. ${CTEST_CONFIGURATION_TYPE} is known
      # only at ctest runtime (by calling ctest -c <Configuration>), so
      # we have to escape $ to delay variable substitution here.
      add_test(
        ${name}
        ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/test/${name}.py
          --build_dir=${CMAKE_CURRENT_BINARY_DIR}/\${CTEST_CONFIGURATION_TYPE})
    endif (${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION} GREATER 3.1)
  endif(PYTHONINTERP_FOUND)
endfunction()

# Adds the given macro definition to the interface of the target when compiling as shared library and msvc.
function( add_export_macro_interface_defintion target definition )
  if(MSVC)
    get_property(type TARGET ${target} PROPERTY TYPE)
    if( ${type} STREQUAL SHARED_LIBRARY )
      target_compile_definitions( ${target} INTERFACE ${definition})
    endif()
  endif()
endfunction()

# add_install_rules( package targets)
#
# Adds install rules for the GMock and GTest packages.
function( add_install_rules package targets )

  set(config_install_dir "${CMAKE_INSTALL_LIBDIR}/cmake/${package}")

  set(generated_dir "${CMAKE_CURRENT_BINARY_DIR}/generated")

  # Configuration
  set(version_config "${generated_dir}/${package}ConfigVersion.cmake")
  set(project_config "${generated_dir}/${package}Config.cmake")
  set(targets_export_name "${package}Targets")
  set(namespace "${package}::")

  # Include module with fuction 'write_basic_package_version_file'
  include(CMakePackageConfigHelpers)

  # Configure '<PROJECT-NAME>ConfigVersion.cmake'
  # Note: PROJECT_VERSION is used as a VERSION
  write_basic_package_version_file(
    "${version_config}" COMPATIBILITY SameMajorVersion
  )

  # Configure '<PROJECT-NAME>Config.cmake'
  # Use variables:
  #   * targets_export_name
  #   * PROJECT_NAME
  configure_package_config_file(
    "cmake/Config.cmake.in"
    "${project_config}"
    INSTALL_DESTINATION "${config_install_dir}"
  )

  # Targets:
  install(
    TARGETS ${targets}
    EXPORT "${targets_export_name}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
    INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
  )

  # Headers:
  string(TOLOWER ${package} package_lower)
  install(
    DIRECTORY ${${package_lower}_SOURCE_DIR}/include/${package_lower}
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
    FILES_MATCHING PATTERN "*.h"
  )

  # Config
  install(
    FILES "${project_config}" "${version_config}"
    DESTINATION "${config_install_dir}"
  )

  # Config
  install(
    EXPORT "${targets_export_name}"
    NAMESPACE "${namespace}"
    DESTINATION "${config_install_dir}"
  )

  # Debug information .pdb for MSVC
  foreach(target ${targets})
    install_pdb_files(${target})
  endforeach()

endfunction()


# install_pdb_files( target )
#
# Makes sure that compiler and linker generated .pdb files ares installed
# when compiling with MSVC and debug options.
function( install_pdb_files target )
  if( NOT ${CMAKE_VERSION} VERSION_LESS 3.1.0)    # COMPILE_PDB_... properties where introduced with cmake 3.1
    foreach( config ${CMAKE_BUILD_TYPE} ${CMAKE_CONFIGURATION_TYPES})
      string( TOUPPER ${config} config_suffix)

      get_property( name_config_postfix TARGET ${target} PROPERTY ${config_suffix}_POSTFIX )
      set( output_dir ${CMAKE_CURRENT_BINARY_DIR}/${config}  )

      # Set output names and install rules for .pdb files that are generated by the compiler
      target_has_pdb_compile_output( has_pdb_compiler_output ${target} ${config})
      if(has_pdb_compiler_output)
        
        set( output_name ${target}${name_config_postfix}-compiler )
        set_property( TARGET ${target} PROPERTY COMPILE_PDB_NAME_${config_suffix} ${output_name} )
        set_property( TARGET ${target} PROPERTY COMPILE_PDB_OUTPUT_DIRECTORY_${config_suffix} ${output_dir} )

        install( 
          FILES ${output_dir}/${output_name}.pdb
          DESTINATION "${CMAKE_INSTALL_LIBDIR}"
          CONFIGURATIONS ${config}
        )

      endif()

      # Set output names and install rules for .pdb files that are generated by the linker
      target_has_pdb_linker_output( has_pdb_linker_output ${target} ${config})
      if(has_pdb_linker_output)

        set( output_name ${target}${name_config_postfix}-linker )
        set_property( TARGET ${target} PROPERTY PDB_NAME_${config_suffix} ${output_name} )
        set_property( TARGET ${target} PROPERTY PDB_OUTPUT_DIRECTORY_${config_suffix} ${output_dir} )

        install( 
          FILES ${output_dir}/${output_name}.pdb
          DESTINATION "${CMAKE_INSTALL_BINDIR}"
          CONFIGURATIONS ${config}
        )

      endif()

    endforeach()
  endif()
endfunction()

# Checks if the compile flags of the given target and configuration
# are set to create the .pdb debug files of the msvc compiler.
function( target_has_pdb_compile_output bOut target config )
  string( TOUPPER ${config} config_suffix)
  flags_contain_debug_flags( has_pdb_flags "${CMAKE_CXX_FLAGS_${config_suffix}} ${CMAKE_CXX_FLAGS}")
  set( ${bOut} ${has_pdb_flags} PARENT_SCOPE )
endfunction()

# Takes a compile flags string as argument and returns true if it contains the /Zi or /ZI flags. 
function( flags_contain_debug_flags bOut flags )
  if(MSVC)
    has_substring( has_flag1 ${flags} /ZI )
    has_substring( has_flag2 ${flags} /Zi )
    if( has_flag1 OR has_flag2)
      set( ${bOut} TRUE PARENT_SCOPE)
      return()
    endif()
  endif()
  set( ${bOut} FALSE PARENT_SCOPE)
endfunction()

# Checks if the compile flags of the given target and configuration
# are set to create the .pdb debug files that are generated by the linker.
function( target_has_pdb_linker_output bOut target config )
    target_has_pdb_compile_output( has_pdb_compile_output ${target} ${config} )
    if(has_pdb_compile_output)
      get_property( target_type TARGET ${target} PROPERTY TYPE)
      if(${target_type} STREQUAL SHARED_LIBRARY OR ${target_type} STREQUAL MODULE_LIBRARY OR ${target_type} STREQUAL EXECUTABLE)
        set(${bOut} TRUE PARENT_SCOPE)
        return()
      endif()
    endif()
    set(${bOut} FALSE PARENT_SCOPE)
endfunction()

# Returns true if a given string contains the given substring.
function( has_substring bOut string substring )
  string(FIND ${string} ${substring} index)
  if( ${index} GREATER -1 )
    set( ${bOut} TRUE PARENT_SCOPE)
  else()
    set( ${bOut} FALSE PARENT_SCOPE)
  endif()
endfunction()
