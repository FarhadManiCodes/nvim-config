# LSP Testing Guide for Neovim Configuration

> **Partially stale — read this first (checked 2026-08).** Written December 2025,
> when three servers were configured. There are now **eight**: clangd,
> basedpyright, **ruff**, bashls, yamlls, jsonls, tinymist and **lua_ls**.
>
> What still applies: everything below about clangd, basedpyright and bashls —
> the setup, `compile_commands.json`, and the test procedures are unchanged.
>
> What it does not cover: ruff, yamlls, jsonls, tinymist, lua_ls. Two points
> matter most for Python, because they changed after this was written:
> **basedpyright does not format** (`textDocument/formatting` is `false`) — ruff
> does, manually via `<leader>cf`, and `*.py` is deliberately out of the
> format-on-save glob. And undefined-name diagnostics belong to basedpyright, not
> ruff, because auto-import hangs off `reportUndefinedVariable`.
>
> Sandbox for the Python half: `~/learning/playground/python-lsp-tests`
> (`bash run.sh`, 13 checks).

**Date:** December 2025
**Target Languages:** C/C++ (primary), Python, Bash
**LSP Servers covered here:** clangd, basedpyright, bash-language-server

---

## 📋 Table of Contents

1. [Initial Setup Verification](#initial-setup-verification)
2. [LSP Server Installation](#lsp-server-installation)
3. [C++ Testing (clangd - Primary Focus)](#c-testing-clangd---primary-focus)
4. [Python Testing (basedpyright)](#python-testing-basedpyright)
5. [Bash Testing (bash-language-server)](#bash-testing-bash-language-server)
6. [Completion Testing](#completion-testing)
7. [Performance Benchmarks](#performance-benchmarks)
8. [Troubleshooting](#troubleshooting)

---

## Initial Setup Verification

### 1. Check Neovim Configuration Loads

```bash
# Start Neovim and check for errors
nvim

# Inside Neovim, check for any error messages
:messages

# Verify no startup errors
# Expected: No red error messages
```

### 2. Verify Plugins Installed

```vim
" Open lazy.nvim UI
:Lazy

" Look for these plugins (should be installed):
" ✓ nvim-lspconfig
" ✓ nvim-cmp
" ✓ cmp-nvim-lsp
" ✓ cmp-buffer
" ✓ cmp-path
```

### 3. Check Configuration Files Exist

```bash
# Verify all LSP config files created
ls -la ~/.config/nvim/lua/config/lsp.lua
ls -la ~/.config/nvim/lua/config/completion.lua
ls -la ~/.config/clangd/config.yaml

# All should exist and be readable
```

---

## LSP Server Installation

### Verify LSP Servers Installed

```bash
# Check clangd (C/C++)
clangd --version
# Expected: clangd version 18.0.0 or higher

# Check basedpyright (Python)
basedpyright --version
# Expected: basedpyright 1.x.x

# Check bash-language-server (Bash)
bash-language-server --version
# Expected: 5.x.x or higher
```

### Install Missing Servers

```bash
# C/C++ (clangd)
sudo pacman -S clang

# Python (basedpyright) - Install in active venv
uv pip install basedpyright
# Or: pip install basedpyright

# Bash (bash-language-server)
sudo pacman -S bash-language-server

# Optional: shellcheck (for bash linting)
sudo pacman -S shellcheck
```

---

## C++ Testing (clangd - Primary Focus)

### Test 1: Basic C++ File Without Project

Create a simple test file to verify clangd works standalone:

```bash
# Create test file
cat > /tmp/test_simple.cpp << 'EOF'
#include <iostream>
#include <vector>

int main() {
    std::vector<int> numbers = {1, 2, 3, 4, 5};

    // Test 1: Hover on 'vector' - should show type info
    // Place cursor on 'vector' and press 'K'

    // Test 2: Type 'numbers.' and trigger completion
    // Should see: push_back, size, empty, etc.
    numbers.

    return 0;
}
EOF

# Open in Neovim
nvim /tmp/test_simple.cpp
```

**Expected behavior:**
1. Wait 1-2 seconds for clangd to initialize
2. Bottom right should show "clangd" LSP attached
3. Check with `:LspInfo` - should show clangd attached
4. Hover on `vector` (press `K`) - should show type documentation
5. Type `numbers.` - completion menu should appear with vector methods

### Test 2: C++ Project with compile_commands.json

Create a minimal CMake project to test full clangd functionality:

```bash
# Create test project
mkdir -p /tmp/cpp_test
cd /tmp/cpp_test

# Create CMakeLists.txt
cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.15)
project(test_project CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(main main.cpp math_utils.cpp)
EOF

# Create main.cpp
cat > main.cpp << 'EOF'
#include "math_utils.h"
#include <iostream>

int main() {
    int result = add(5, 3);
    std::cout << "Result: " << result << std::endl;

    // Test: Go to definition of 'add' (gd)
    // Test: Find references of 'add' (gr)

    return 0;
}
EOF

# Create math_utils.h
cat > math_utils.h << 'EOF'
#ifndef MATH_UTILS_H
#define MATH_UTILS_H

// Simple addition function
int add(int a, int b);

// Simple multiplication function
int multiply(int a, int b);

#endif
EOF

# Create math_utils.cpp
cat > math_utils.cpp << 'EOF'
#include "math_utils.h"

int add(int a, int b) {
    return a + b;
}

int multiply(int a, int b) {
    return a * b;
}
EOF

# Build to generate compile_commands.json
mkdir build
cd build
cmake ..
cd ..

# Symlink compile_commands.json to root (required for clangd)
ln -sf build/compile_commands.json .

# Verify it exists
ls -la compile_commands.json
```

**Open project and test:**

```bash
# Open project in Neovim
cd /tmp/cpp_test
nvim main.cpp
```

**Test cases:**

1. **Go to definition (gd)**:
   - Place cursor on `add` in `main.cpp`
   - Press `gd`
   - Should jump to `math_utils.cpp` definition

2. **Find references (gr)**:
   - Place cursor on `add` in `math_utils.h`
   - Press `gr`
   - Should show Telescope picker with all usages

3. **Hover documentation (K)**:
   - Place cursor on `add`
   - Press `K`
   - Should show function signature

4. **Code actions (<leader>ca)**:
   - Remove `#include "math_utils.h"` from main.cpp
   - Place cursor on `add` (will have red underline)
   - Press `<leader>ca`
   - Should offer "Add include" action

5. **Include completion**:
   - Start typing: `#include <vec`
   - Completion should suggest `<vector>`

### Test 3: Trilinos-Style Template Code

Create a test file mimicking Trilinos Tpetra template complexity:

```bash
cat > /tmp/test_tpetra_style.cpp << 'EOF'
#include <memory>
#include <vector>

// Mimic Trilinos Tpetra template style
template<typename Scalar, typename LocalOrdinal, typename GlobalOrdinal>
class FakeMatrix {
public:
    using scalar_type = Scalar;
    using local_ordinal_type = LocalOrdinal;
    using global_ordinal_type = GlobalOrdinal;

    void insertGlobalValues(GlobalOrdinal row,
                           const std::vector<GlobalOrdinal>& indices,
                           const std::vector<Scalar>& values) {
        // Implementation
    }

    GlobalOrdinal getGlobalNumRows() const {
        return num_rows_;
    }

private:
    GlobalOrdinal num_rows_;
};

int main() {
    using Scalar = double;
    using LO = int;
    using GO = long;

    // Test: Hover on FakeMatrix to see template expansion
    FakeMatrix<Scalar, LO, GO> matrix;

    // Test: Type 'matrix.' - should see completion with methods
    matrix.

    // Test: Hover on 'getGlobalNumRows' - should show return type
    auto num_rows = matrix.getGlobalNumRows();

    return 0;
}
EOF

nvim /tmp/test_tpetra_style.cpp
```

**Expected behavior:**
- Hover on `FakeMatrix` shows expanded template types
- Completion shows `insertGlobalValues`, `getGlobalNumRows`
- No overwhelming template error noise (thanks to config.yaml suppressions)

---

## Python Testing (basedpyright)

### Test 1: Python Type Checking

```bash
# Create test file
cat > /tmp/test_python.py << 'EOF'
import pandas as pd
from typing import List, Optional

def process_data(df: pd.DataFrame) -> pd.DataFrame:
    # Test 1: Type 'df.' - should show DataFrame methods
    df.

    # Test 2: Hover on 'DataFrame' - should show type info
    result = df.groupby('column').sum()

    return result

def add_numbers(a: int, b: int) -> int:
    # Test 3: Type error - should show diagnostic
    return str(a + b)  # Wrong return type!

# Test 4: Signature help
# Type 'process_data(' and see parameter hints
result = process_data()
EOF

# Activate a venv with pandas and basedpyright
# (Adjust to your workflow)
nvim /tmp/test_python.py
```

**Expected behavior:**
1. `:LspInfo` shows `basedpyright` attached
2. Completion on `df.` shows DataFrame methods
3. Red underline on `return str(a + b)` (type error)
4. Press `<leader>e` to see diagnostic: "Expected int, got str"

### Test 2: Python Without Type Hints

```bash
cat > /tmp/test_python_dynamic.py << 'EOF'
# Dynamic Python (no type hints)
def calculate(x, y):
    # Completion still works for built-in types
    result = x + y

    # Test: Type 'result.' - should show basic completions
    result.

    return result

# Lists and dicts
data = [1, 2, 3, 4, 5]
# Test: Type 'data.' - should show list methods
data.

config = {"key": "value"}
# Test: Type 'config.' - should show dict methods
config.
EOF

nvim /tmp/test_python_dynamic.py
```

**Expected behavior:**
- Basic completion works even without type hints
- Buffer completion suggests variable names
- No false-positive errors

---

## Bash Testing (bash-language-server)

### Test 1: Shell Script Linting

```bash
cat > /tmp/test_script.sh << 'EOF'
#!/bin/bash

# Test 1: Shellcheck integration
# This should show a warning (quote variables)
filename=$1
rm $filename  # Should warn: quote variable

# Test 2: Completion
# Type 'local ' and see variable completions

function process_file() {
    local input_file="$1"

    # Test 3: Hover on 'basename' - should show man page
    basename "$input_file"

    # Test 4: Code action on unquoted variable
    echo $input_file  # Should suggest quoting
}

# Test 5: Find references
process_file "test.txt"
EOF

chmod +x /tmp/test_script.sh
nvim /tmp/test_script.sh
```

**Expected behavior:**
1. `:LspInfo` shows `bashls` attached
2. Warnings on unquoted variables (if shellcheck installed)
3. Hover on builtins shows documentation
4. `gd` on function names jumps to definition

---

## Completion Testing

### Test Completion Sources

Open any file and test completion priorities:

```vim
" In C++ file:
" Type a function name - should prioritize LSP
" Type a long template typename from earlier in file - buffer should suggest

" In Python file:
" Type 'import ' - should show module completions (path source)
" Type method name - LSP suggestions appear first

" Test manual trigger:
" <C-Space> - Should open completion menu
" <C-n> / <Tab> - Navigate down
" <C-p> / <S-Tab> - Navigate up
" <CR> - Confirm
" <C-e> - Close menu
```

### Test Completion Keybindings

```vim
" Insert mode tests:
:help insert-mode

" Type some text, then:
" <C-Space> - Triggers completion
" <Tab> - Next item
" <S-Tab> - Previous item
" <CR> - Confirms selection (only if item selected)
" <C-e> - Aborts completion
```

---

## Performance Benchmarks

### Measure Startup Time

```bash
# With LSP configuration
nvim --startuptime /tmp/nvim_startup.log test.cpp
cat /tmp/nvim_startup.log | tail -n 20

# Look for total time (should be < 150ms)
```

### Measure clangd Indexing Time

```bash
# Small project (< 10 files)
cd /tmp/cpp_test
time nvim -c "sleep 5 | qa" main.cpp

# Expected: < 5 seconds until usable
```

### Check clangd Memory Usage

```bash
# While Neovim is open with C++ file
ps aux | grep clangd

# Look at RSS (resident memory)
# Expected: 500MB - 2GB (depends on project size)
# Acceptable: up to 4GB (you have 64GB RAM)
```

### Test Completion Latency

```vim
" In C++ file, type:
" std::vector<int> v;
" v.
"
" Time from '.' to menu appearing:
" Expected: < 100ms
" Acceptable: < 200ms
```

---

## Troubleshooting

### Issue: LSP Not Attaching

**Symptoms:** No completions, no hover, `:LspInfo` shows "0 clients attached"

**Solutions:**

```vim
" Check if LSP should attach to this filetype
:set filetype?
" Expected for C++: cpp
" Expected for Python: python

" Manually trigger LSP start
:LspStart clangd

" Check for errors
:LspInfo
:messages

" Check if LSP server is installed
:!which clangd
:!which basedpyright
:!which bash-language-server
```

### Issue: No Completions Appearing

**Symptoms:** LSP attached, but no completion menu

**Solutions:**

```vim
" Check completion status
:CmpStatus

" Verify sources are active
" Expected: nvim_lsp, buffer, path

" Try manual trigger
<C-Space>

" Check if large file disabled LSP
:lua print(vim.b.large_file)
" Expected: nil (false)

" Check completeopt
:set completeopt?
" Expected: menu,menuone,noselect
```

### Issue: clangd Can't Find Headers

**Symptoms:** Red underlines on `#include`, "file not found" errors

**Solutions:**

```bash
# 1. Verify compile_commands.json exists
ls -la compile_commands.json

# 2. Check it's valid JSON
cat compile_commands.json | jq

# 3. Verify include paths are correct
cat compile_commands.json | jq '.[0].command'
# Should see -I flags for header directories

# 4. Regenerate compile_commands.json
cd build
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
cd ..
ln -sf build/compile_commands.json .

# 5. Restart LSP
# In Neovim:
:LspRestart
```

### Issue: Too Many Warnings/Diagnostics

**Symptoms:** Red underlines everywhere, noisy warnings

**Solutions:**

```yaml
# Edit ~/.config/clangd/config.yaml
# Add more suppressions:

Diagnostics:
  Suppress:
    - unused-parameter
    - deprecated-declarations
    - unknown-pragmas
    - unused-local-typedef
    - sign-compare              # Add if needed
    - unused-variable           # Add if needed
```

```vim
" Temporarily disable diagnostics
:lua vim.diagnostic.disable()

" Re-enable
:lua vim.diagnostic.enable()

" Adjust diagnostic level
:lua vim.diagnostic.config({ severity_sort = true, virtual_text = false })
```

### Issue: Slow Performance

**Symptoms:** Lag while typing, slow completions

**Solutions:**

```vim
" 1. Check if file is too large
:lua print(vim.fn.line('$'))
" If > 10,000 lines, consider disabling LSP

" 2. Check clangd memory
:!ps aux | grep clangd

" 3. Reduce clangd parallel jobs
" Edit lua/config/lsp.lua
" Change: "-j=8" to "-j=4"

" 4. Disable background indexing
" Edit ~/.config/clangd/config.yaml
" Background: Skip

" 5. Check for infinite indexing loops
:LspLog
" Look for repeated "Indexing" messages
```

### Issue: basedpyright Not Found in Venv

**Symptoms:** Python LSP not attaching, "basedpyright not found"

**Solutions:**

```bash
# 1. Check if basedpyright is in current venv
which basedpyright
# Should be: /path/to/venv/bin/basedpyright

# 2. Install in venv
uv pip install basedpyright
# Or: pip install basedpyright

# 3. Verify it's executable
basedpyright --version

# 4. Restart Neovim
```

### Issue: Bash LSP Not Working

**Symptoms:** No completions or diagnostics in `.sh` files

**Solutions:**

```bash
# 1. Check bash-language-server installed
which bash-language-server

# 2. Install if missing
sudo pacman -S bash-language-server

# 3. Check shellcheck installed (optional but recommended)
which shellcheck
sudo pacman -S shellcheck

# 4. Verify filetype detection
# In Neovim:
:set filetype?
# Expected: sh
```

### Issue: Keybindings Not Working

**Symptoms:** `gd`, `gr`, `K` don't work

**Solutions:**

```vim
" 1. Verify LSP is attached
:LspInfo
" Should show client attached to buffer

" 2. Check buffer-local mappings
:verbose map gd
" Should show mapping to vim.lsp.buf.definition

" 3. Try explicit command
:lua vim.lsp.buf.definition()

" 4. Check for conflicting plugins
" Look in plugins/init.lua for any plugin that maps 'gd'
```

---

## Quick Reference: Essential Commands

```vim
" LSP Information
:LspInfo              " Show attached LSP clients
:LspLog               " View LSP logs
:LspRestart           " Restart LSP server

" Completion
:CmpStatus            " Show completion sources

" Diagnostics
:lua vim.diagnostic.setloclist()  " Send diagnostics to location list
:lua vim.diagnostic.disable()      " Temporarily disable diagnostics
:lua vim.diagnostic.enable()       " Re-enable diagnostics

" Testing
:messages             " View all messages
:checkhealth          " Full health check
:checkhealth lsp      " LSP-specific health check
```

---

## Success Criteria Checklist

After testing, verify the following work:

### C++ (clangd)
- [ ] LSP attaches to `.cpp` and `.h` files
- [ ] `gd` (go to definition) works
- [ ] `gr` (find references) opens Telescope picker
- [ ] `K` (hover) shows function signatures
- [ ] Completion shows methods after `.` and `->`
- [ ] Include completion suggests headers
- [ ] Code actions offer to add missing includes
- [ ] Diagnostics show as red underlines (no virtual text)
- [ ] Large files (>10MB) disable LSP automatically

### Python (basedpyright)
- [ ] LSP attaches to `.py` files
- [ ] Type checking shows errors (wrong return types, etc.)
- [ ] Completion works with and without type hints
- [ ] `gd` jumps to function definitions
- [ ] Hover shows type information

### Bash (bash-language-server)
- [ ] LSP attaches to `.sh`, `.bash`, `.zsh` files
- [ ] Shellcheck warnings appear (if installed)
- [ ] Hover on builtins shows documentation
- [ ] `gd` works on functions

### Completion (nvim-cmp)
- [ ] Completion menu appears automatically after typing
- [ ] LSP suggestions appear first
- [ ] Buffer and path suggestions also available
- [ ] Keybindings work (`<C-Space>`, `<Tab>`, `<CR>`, `<C-e>`)
- [ ] Autopairs integration works (auto-insert parentheses)

### Performance
- [ ] Startup time < 150ms
- [ ] clangd indexing < 5 seconds (small projects)
- [ ] Completion latency < 100ms
- [ ] clangd memory usage < 5GB

---

## Next Steps After Testing

1. **Install LSP servers** if any are missing (see installation section)
2. **Create compile_commands.json** for your C++ projects
3. **Adjust clangd config** if you see too many warnings
4. **Add snippets** if needed (LuaSnip + cmp_luasnip)
5. **Customize keybindings** if defaults conflict with your workflow

---

## Additional Resources

- clangd documentation: https://clangd.llvm.org/
- basedpyright: https://github.com/DetachHead/basedpyright
- nvim-cmp: https://github.com/hrsh7th/nvim-cmp
- nvim-lspconfig: https://github.com/neovim/nvim-lspconfig

---

**Happy coding with LSP! 🚀**
