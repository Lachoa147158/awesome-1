# Module is designed to allow the Awesome documentation examples to be tested.
#
# It shim enough of Awesome C API to allow code to be executed without an
# actual X server or running Awesome process. These test are not genuine
# integration tests, but they are the next best thing.
#
# As secondary goals, this module also generate images of the test result where
# relevant. Those images are used by the documentation and help developpers
# track user interface regressions and glitches. Finally, it also help to find
# broken code.
cmake_minimum_required(VERSION 3.0.0)

# Get and update the LUA_PATH so the scripts can be executed without Awesome
execute_process(COMMAND lua -e print\(package.path\) OUTPUT_VARIABLE "LUA_PATH_")

# Add the main awesome lau libraries
# set(${LUA_PATH_} "${SOURCE_DIR}/lib/?;${SOURCE_DIR}/lib/?.lua;${LUA_PATH_}")
set(LUA_PATH2_ "\
${CMAKE_SOURCE_DIR}/lib/?/init.lua;\
${CMAKE_SOURCE_DIR}/lib/?;\
${CMAKE_SOURCE_DIR}/lib/?.lua;"
)

# Add the C API shims
# set(${LUA_PATH_} "${SOURCE_DIR}/lib/?;${SOURCE_DIR}/lib/?.lua;${LUA_PATH_}")
set(LUA_PATH3_ "\
${CMAKE_SOURCE_DIR}/tests/examples/shims/?/init.lua;\
${CMAKE_SOURCE_DIR}/tests/examples/shims/?;\
${CMAKE_SOURCE_DIR}/tests/examples/shims/?.lua;"
)

# Done in 3 variables to avoid CMake from implicitly converting into a list
set(ENV{LUA_PATH} "${LUA_PATH3_}${LUA_PATH2_}${LUA_PATH_}")

# The documentation images directory
set(IMAGE_DIR "${CMAKE_BINARY_DIR}/doc/images")
file(MAKE_DIRECTORY "${IMAGE_DIR}")

# Escape potentially multiline strings to be part of the API doc
#  * add "--" in front of each lines
#  * add a custom prefix in front of each lines
#  * drop empty lines
#  * convert " " lines into empty lines
#  * drop lines ending with "--DOC_HIDE"
function(escape_string variable content escaped_content line_prefix)
    string(REGEX REPLACE "\n" ";" var_lines "${variable}")

    set(tmp_output ${content})
    foreach (EXAMPLE_FILE ${var_lines})
        if(NOT EXAMPLE_FILE MATCHES "^.+--DOC_HIDE$")
            set(tmp_output ${tmp_output}\n--${line_prefix}${EXAMPLE_FILE})
        endif()
    endforeach()

    set(${escaped_content} ${tmp_output} PARENT_SCOPE)
endfunction()

# Read a code file and convert it to ldoc usage example
#  * add "--" in front of each lines
#  * drop empty lines
#  * convert " " lines into empty lines
#  * drop lines ending with "--DOC_HIDE"
function(escape_code path content escaped_content)
    file(READ ${path} path)

    escape_string("${path}\n " "${content}" content "")

    set(${escaped_content} ${content} PARENT_SCOPE)
endfunction()

# Execute a lua file
function(run_test test_path namespace template escaped_content)

    # Get the file name without the extension
    get_filename_component(${test_path} TEST_FILE_NAME NAME)
    set(IMAGE_PATH "${IMAGE_DIR}/${namespace}_${TEST_FILE_NAME}")

    #message("-- Testing module ${namespace}_${TEST_FILE_NAME}")

    # Execute the script, leave the image extension decision to the test
    # SVG is preferred, but PNG is better suited for some tests, like bitmap
    # patterns.
    execute_process(
        COMMAND lua ${template} ${test_path} ${IMAGE_PATH}
        OUTPUT_VARIABLE TEST_OUTPUT
        ERROR_VARIABLE  TEST_ERROR
    )

    # If there is something on stderr, exit
    if (NOT TEST_ERROR STREQUAL "")
        message(${TEST_OUTPUT})
        message(${TEST_ERROR})
        message(FATAL_ERROR ${test_path} " A test failed, bye")
    endif()

    # Build the documentation
    set(TEST_DOC_CONTENT "")

    # If the image has been created, then add it.
    if (EXISTS "${IMAGE_PATH}.svg") #TODO support png
        escape_string(
            "![Usage example](${IMAGE_PATH}.svg)\n "
            "${TEST_DOC_CONTENT}" TEST_DOC_CONTENT ""
        )
    endif()

    # If there is an output, assume it is relevant and add it to the
    # documentation under the image.
    if(NOT ${TEST_OUTPUT} STREQUAL "")
        escape_string(
            " **Usage output:**"
            "${TEST_DOC_CONTENT}" TEST_DOC_CONTENT ""
        )

        # Markdown require an empty line before and after + 4 spaces
        escape_string(
            "\n \n${TEST_OUTPUT}\n "
            "${TEST_DOC_CONTENT}" TEST_DOC_CONTENT "    "
        )
    endif()

    escape_string(
        " @usage"
        "${TEST_DOC_CONTENT}" TEST_DOC_CONTENT ""
    )

    escape_code(${test_path} ${TEST_DOC_CONTENT} TEST_DOC_CONTENT)

    # Export the outout to the parent scope
    set(${escaped_content} "${TEST_DOC_CONTENT}" PARENT_SCOPE)

endfunction()

# Recursive helper function to avoid adding CMakeLists.txt and add_subdirectory
# in every sub-directories
function(digg path namespace template)
    # Get the directory content
    file(GLOB ex_files RELATIVE "${path}"
        "${path}/*")

    foreach(ex_file_name ${ex_files})
        if(IS_DIRECTORY ${path}/${ex_file_name}
            AND (NOT ${ex_file_name} STREQUAL "shims"))

            # Check if there is a template for this directory, else use the
            # last known one.
            if(EXISTS ${path}/template.lua)
                digg("${path}/${ex_file_name}" "${namespace}_${ex_file_name}" ${path}/template.lua)
            else()
                digg("${path}/${ex_file_name}" "${namespace}_${ex_file_name}" ${template})
            endif()

        elseif(${ex_file_name} MATCHES ".lua"
            AND NOT ${ex_file_name} MATCHES "template.lua")

            # Get the file name without the extension
            string(REGEX REPLACE "\\.lua" "" TEST_FILE_NAME ${ex_file_name})

            run_test("${path}/${ex_file_name}" "${namespace}" ${template} ESCAPED_CODE_EXAMPLE)

            # Set the test name
            set(TEST_NAME DOC${namespace}_${TEST_FILE_NAME}_EXAMPLE)

            # Anything called @DOC_`namespace`_EXAMPLE@
            # in the Lua or C sources will be replaced by the content if that
            # variable during the pre-processing
            set(ENV{${TEST_NAME}} "${ESCAPED_CODE_EXAMPLE}" CACHE INTERNAL FORCE)

            # Update the test list
            set(ENV{EXAMPLE_LIST} "$ENV{EXAMPLE_LIST};${TEST_NAME}")

        endif()
    endforeach()
endfunction()

# Start at the top level then recursively explore the sub-directories to locate
# the test. In parallel, build a namespace for the global variables. Those
# variables will be inserted into the lua source code itself once the examples
# are validated.
digg("${SOURCE_DIR}/tests/examples" "" " ")

# This is ugly, but CMake variable scope system totally ignore 50 years of
# computer science evolution and only support function local variables.
# PARENT_SCOPE is useless in recursive methods and the CMake pre-processor
# can't access ENV variables. So the only (insane) way is to set tons of ENV
# variables, keep track of them in yet another one and set them in the global
# scope once in the "top level" CMakeLists section (it cannot be done from
# functions)
foreach(vari $ENV{EXAMPLE_LIST})
    # While at it, replace \" created by CMake by ', &quot; wont work in <code>
    string(REGEX REPLACE "\\\"" "'" ${vari} $ENV{${vari}})
endforeach()
