#!/usr/bin/env bats
# Source: bats-core tutorial https://bats-core.readthedocs.io/en/stable/tutorial.html

setup() {
  # Resolve plugin path relative to this test file
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PLUGIN="$DIR/../kubectl-mns"

  # Create kubectl stub
  STUB_DIR="$(mktemp -d)"
  STUB_CALL_LOG="$STUB_DIR/kubectl.log"

  cat > "$STUB_DIR/kubectl" << 'EOF'
#!/usr/bin/env bash
echo "$@" >> "$STUB_CALL_LOG"
echo "stub output"
exit 0
EOF
  chmod +x "$STUB_DIR/kubectl"
  export PATH="$STUB_DIR:$PATH"
  export STUB_CALL_LOG
  export PLUGIN
}

teardown() {
  rm -rf "$STUB_DIR"
}

# TESTS-02: no namespace → defaults to "default"
@test "TESTS-02: no namespace defaults to 'default'" {
  run "$PLUGIN" -- get pods
  [ "$status" -eq 0 ]
  rg -qF -- "--namespace default" "$STUB_CALL_LOG"
}

# TESTS-03: multiple namespaces → one kubectl call per namespace
@test "TESTS-03: multiple namespaces — one kubectl call per namespace" {
  run "$PLUGIN" ns1 ns2 -- get pods
  [ "$status" -eq 0 ]
  call_count=$(wc -l < "$STUB_CALL_LOG")
  [ "$call_count" -eq 2 ]
  rg -qF -- "--namespace ns1" "$STUB_CALL_LOG"
  rg -qF -- "--namespace ns2" "$STUB_CALL_LOG"
  [[ "$output" == *"=== namespace: ns1 ==="* ]]
  [[ "$output" == *"=== namespace: ns2 ==="* ]]
}

# TESTS-04: --all-namespaces and -A stripped from forwarded args
@test "TESTS-04: --all-namespaces and -A stripped from forwarded args" {
  run "$PLUGIN" ns1 -- get pods --all-namespaces -A
  [ "$status" -eq 0 ]
  ! rg -qF -- "--all-namespaces" "$STUB_CALL_LOG"
  ! rg -qF -- " -A" "$STUB_CALL_LOG"
}

# TESTS-05: empty kubectl args → exit 1 and prints usage
@test "TESTS-05: no kubectl args exits 1 and prints usage" {
  run "$PLUGIN" --
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

# TESTS-06: -h and --help print usage and exit 0
@test "TESTS-06: -h and --help print usage and exit 0" {
  run "$PLUGIN" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]

  run "$PLUGIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# TESTS-07: namespace failure continues to next namespace
@test "TESTS-07: namespace failure continues to next namespace" {
  # Override stub to fail for ns1
  cat > "$STUB_DIR/kubectl" << 'STUBEOF'
#!/usr/bin/env bash
echo "$@" >> "$STUB_CALL_LOG"
if [[ "$*" == *"--namespace ns1"* ]]; then
  exit 1
fi
echo "stub output"
exit 0
STUBEOF
  chmod +x "$STUB_DIR/kubectl"

  run "$PLUGIN" ns1 ns2 -- get pods
  [ "$status" -eq 0 ]
  rg -qF -- "--namespace ns1" "$STUB_CALL_LOG"
  rg -qF -- "--namespace ns2" "$STUB_CALL_LOG"
  [[ "$output" == *"Error"* ]]
}

# TESTS-01: test file exists and is readable by bats
@test "TESTS-01: test file exists and is readable by bats" {
  [ -f "$BATS_TEST_FILENAME" ]
  [ -r "$BATS_TEST_FILENAME" ]
}
