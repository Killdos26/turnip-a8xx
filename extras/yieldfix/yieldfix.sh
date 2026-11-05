#!/bin/sh
# yieldfix.sh - libyieldfix.so를 켜고 게임을 실행한다.
#
# Steam 실행 옵션:
#   sh /mnt/droiddeck-sd/yieldfix.sh %command%
# 잠드는 시간 바꾸기:  YF_SLEEP_US=20 sh /mnt/droiddeck-sd/yieldfix.sh %command%
# 잠깐 끄기:           YF=0 sh /mnt/droiddeck-sd/yieldfix.sh %command%
#
# SD카드는 noexec라 .so를 그 자리에서 불러올 수 없으므로 /tmp(안 되면 $HOME)로 복사해서 쓴다.

DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd || dirname "$0")

if [ "${YF:-1}" != 0 ] && [ -f "$DIR/libyieldfix.so" ]; then
  for d in "${TMPDIR:-/tmp}" "$HOME"; do
    [ -n "$d" ] || continue
    if cp "$DIR/libyieldfix.so" "$d/libyieldfix.so" 2>/dev/null && chmod 755 "$d/libyieldfix.so" 2>/dev/null; then
      rest=$(printf '%s' "${LD_PRELOAD:-}" | tr ': ' '\n\n' | grep -v -e 'libyieldfix' -e 'libyieldcount' | grep -v '^$' | paste -sd: -)
      export LD_PRELOAD="$d/libyieldfix.so${rest:+:$rest}"
      export YF_SLEEP_US="${YF_SLEEP_US:-50}"
      break
    fi
  done
fi

exec "$@"
