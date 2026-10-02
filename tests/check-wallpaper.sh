#!/usr/bin/env bash
# Isolated regression check: no sudo, real rebuild, push, or desktop restart.
set -euo pipefail
source_script=$(cd -- "$(dirname -- "$0")/.." && pwd)/set-wallpaper.sh
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/repo/wallpaper" "$test_dir/bin"
cp "$source_script" "$test_dir/repo/"
printf '#!/usr/bin/env bash\nexit "${TEST_REBUILD_STATUS:-0}"\n' > "$test_dir/bin/sudo"
printf '#!/usr/bin/env bash\ntouch "$TEST_RESTART_MARKER"\n' > "$test_dir/bin/systemctl"
chmod +x "$test_dir/bin/"*
export PATH="$test_dir/bin:$PATH" TEST_RESTART_MARKER="$test_dir/restarted"
cd "$test_dir/repo"
git init -q
git config user.name Test
git config user.email test@example.invalid
printf 'original image\n' > 'wallpaper/source image.jpg'
git add .
git commit -qm initial
printf 'unrelated staged work\n' > unrelated
git add unrelated

# A wallpaper selected from inside wallpaper/ must survive replacement.
bash ./set-wallpaper.sh 'wallpaper/source image.jpg' > "$test_dir/log" 2>&1
test "$(cat wallpaper/wallpaper.jpg)" = 'original image'
test -f "$TEST_RESTART_MARKER"
test "$(git diff --cached --name-only)" = unrelated
if git cat-file -e HEAD:unrelated 2>/dev/null; then exit 1; fi

# Failed rebuilds must not restart the shell; missing inputs must not delete files.
rm "$TEST_RESTART_MARKER"
printf 'new image\n' > "$test_dir/new image.png"
if TEST_REBUILD_STATUS=1 bash ./set-wallpaper.sh "$test_dir/new image.png" >> "$test_dir/log" 2>&1; then exit 1; fi
test ! -e "$TEST_RESTART_MARKER"
if bash ./set-wallpaper.sh "$test_dir/missing.jpg" >> "$test_dir/log" 2>&1; then exit 1; fi
test "$(cat wallpaper/wallpaper.png)" = 'new image'
echo 'PASS: wallpaper input survives, unrelated work stays staged, and failures stop activation.'
