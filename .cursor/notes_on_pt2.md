Perfect! That's a much cleaner approach. Let's update the plan to require `jq` as a dependency and remove all the fallback complexity.

## Updated Plan - Require `jq` as Dependency

### **Immediate Tasks (UX + Correctness)**

1. **Switch `use` to positional form**
   - Change `src/use.sh` to accept `simpleca use <id>` (positional)
   - Remove `use --ca <id>` support
   - Validate CA exists before setting default; friendly error if missing
   - Update help text and tests

2. **Fix global parsing in `src/main.sh`**
   - Replace `[[ $# > 0 ]]` with `[[ $# -gt 0 ]]` in loops
   - Remove extra shift after breaking on first positional
   - Ensure subcommand + args are preserved exactly after global pre-parse

3. **Support `--ca` at subcommand position**
   - Add local parsing of `--ca` to `issue`, `validate`, `export`, `cert-manager`
   - Users can run `simpleca issue --ca <id> ...` or rely on default
   - Document behavior in help

4. **Ensure OpenSSL configs are generated**
   - Call `ensure_per_ca_openssl_configs` early in all CA-dependent commands
   - Not just `init` - also `issue`, `cert-manager`, etc.

### **Registry Simplification (No Fallbacks)**

5. **Remove all jq fallback code**
   - Delete fallback logic in `src/config.sh`
   - Simplify `registry_*` functions to assume `jq` is available
   - Add `jq` to dependency check in `src/common.sh`

6. **Update dependency requirements**
   - Add `jq` to the list of required tools
   - Update error messages to mention `jq` requirement
   - Update README/install docs

### **Security & Non-Interactive**

7. **Harden password reading**
   - Only use `stty -echo` when `[[ -t 0 ]]` (TTY check)
   - Always restore echo safely
   - Clarify non-interactive options in help

8. **File permissions**
   - Confirm private keys are 600/400, public artifacts 644/444
   - Add explicit warning in `export` about private keys inclusion

### **Tests & Documentation**

9. **Update tests**
   - Unit: `use <id>` positional, local `--ca` parsing, global parser correctness
   - Integration: multi-CA workflows, export-import cycles
   - Remove jq fallback tests

10. **Update docs/help**
    - Show `use <id>` positional form
    - Clarify global flag placement
    - Add examples with default vs explicit `--ca`

### **Feature: CA Removal**

11. **Implement `remove` subcommand**
    - `simpleca remove <id> [--force] [--dry-run] [--unregister-only]`
    - Handle default CA removal (require setting different default first)
    - Registry updates using `jq`
    - Tests and documentation

### **CLI Cleanup**

12. **Remove version output**
    - Delete `version` subcommand, `--version` flag, helper, tests
    - Update help to remove version references

### **Developer Experience**

13. **Shell integration**
    - Zsh completion with dynamic CA id completion using `jq`
    - Top-level `simpleca` shim executable

This approach is much cleaner - we can focus on the core functionality without worrying about complex fallback scenarios. Should we start with the `use` positional change and global parsing fixes?
