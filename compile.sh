#!/bin/bash
# Universal C++ compilation utility wrapper for Linux/macOS
# Usage: ./compile.sh <source1.cpp> [source2.cpp] ...
# Calls compile.py which handles smart hash-based caching

python3 compile.py "$@"
exit $?

