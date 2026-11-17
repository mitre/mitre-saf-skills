# Stub check functions used only by run.sh to prove the dispatch contract:
# a per-unit function is called once per unit with the unit path as $1 and
# CUR_TAG set; a _root function is called once with the repo root.
# The real Go G-01 is a _root check, which would win over a per-unit stub, so
# drop it here: the point is to prove per-unit dispatch with the path in $1.
unset -f check_go_G01_root
check_go_G01() { result G-01 "$CUR_TAG" PASS "stub unit=$1"; }
check_javascript_G03_root() { result G-03 "$CUR_TAG" PASS "stub root=$1"; }
