# yieldfix: less CPU on Cyberpunk 2077's busy waits

`libyieldfix.so` is a small `LD_PRELOAD` library that lowers the CPU time
Cyberpunk 2077 spends in busy waits under Proton + FEX. This is not part of
the driver. It came out of a separate investigation of the FEX/CPU side and
is kept here so it is not lost. Experimental, tested only on a Lenovo Legion
Y700 Gen4 (Snapdragon 8 Elite) with DroidDeck.

[한국어는 아래에 있습니다.](#한국어)

## What was found

- Frame rate is limited by one CPU thread, the game's `GameThread`, not by
  the GPU. That is why lowering the resolution does not raise the FPS.
- About 0.5–0.6 of a core of that thread was kernel time. The game busy-waits
  with `SwitchToThread()` / `Sleep(0)`. Wine turns each call into
  `NtYieldExecution`, which is `getrusage` + `sched_yield` + `getrusage`.
  Measured on `GameThread`:
  - about 320,000 `sched_yield` per second, 1.5 µs each
  - about 650,000 `getrusage` per second
  - about 700,000 `clock_gettime` per second
- Ruled out as the cause:
  - FEX's own overhead (JIT, signals and cache together about 2 %)
  - Wine synchronisation (ntsync vs esync)
  - page faults and swap (half the faults, same `GameThread` time)
  - the Turnip driver (its wait paths all block)
  - time queries (the vDSO works, 24 ns)
- Device: 19.2 MHz timer, vDSO present.

## What it does

The library replaces `sched_yield()`. When the same thread yields again
within 200 µs, the call becomes a `nanosleep` of `YF_SLEEP_US` microseconds
(default 50) instead of an immediate yield. It only acts in processes whose
command line contains `Cyberpunk2077.exe`, or the string in `YF_TARGET`.

## Use (DroidDeck)

1. Copy `yieldfix.sh` and `libyieldfix.so` into the SD card folder
   `Android/data/com.antutu.benchmark.full/files/steam/`. Inside DroidDeck's
   Linux guest that folder is `/mnt/droiddeck-sd/` (the path used below and
   in the logs).
2. Set the Steam launch options of the game:

   ```
   sh /mnt/droiddeck-sd/yieldfix.sh %command%
   ```

| Variable | Effect |
|---|---|
| `YF_SLEEP_US=20` | Sleep length in µs (default 50) |
| `YF=0` | Turn it off for one run |
| `YF_TARGET=Name.exe` | Act in another game's processes |

The SD card is mounted `noexec`, so the script copies the library to `/tmp`
(or `$HOME`) and preloads it from there.

## Results so far

- In game, core use dropped from 92–100 % to 56–64 %, the prime cores held
  higher clocks (3.8 GHz) and the device ran cooler. Play felt smoother.
- **Side effect:** when driving fast, the world can stream in late: missing
  ground, or bumping into objects that are not drawn yet. Streaming threads
  probably busy-wait too and now wake up later. A smaller `YF_SLEEP_US`
  (for example 20 or 10) trades some of the CPU saving back for streaming.
- Linux sleeps are rounded up by the thread's timer slack (50 µs by default),
  so a small `YF_SLEEP_US` may sleep longer than asked. Setting
  `prctl(PR_SET_TIMERSLACK, 1)` in the library would make small values
  exact. This is not in the current binary.

## Files

| File | |
|---|---|
| `libyieldfix.so` | aarch64 glibc shared library (imports only `sched_yield`, `nanosleep`, `getenv`, `open`/`read`/`close`, `strstr`), SHA-256 `8156d6be6f479975c4b550c7486851fd2b07571a573bfb5eec2d1623095351c1` |
| `yieldfix.sh` | Launcher that preloads it |

The source of `libyieldfix.so` is not in this repository yet.

---

## 한국어

`libyieldfix.so`는 Proton + FEX에서 사이버펑크 2077이 바쁜 대기에 쓰는 CPU를 줄여 주는 작은 `LD_PRELOAD` 라이브러리예요.
- 드라이버와는 별개예요. FEX와 CPU 쪽 조사에서 나온 결과라, 잃어버리지 않게 여기 보관해요.
- Legion Y700 4세대와 DroidDeck에서만 시험했어요.

### 조사에서 알아낸 것
- FPS는 게임 메인 스레드(`GameThread`) 하나가 정해요. 해상도와는 상관없어요.
- 이 스레드의 커널 시간(약 0.5~0.6코어)은 게임이 `SwitchToThread()`나 `Sleep(0)`으로 바쁘게 기다리는 데서 나와요.
  - Wine이 이걸 매번 `getrusage` + `sched_yield` + `getrusage`로 처리해요. 호출 한 번에 시스템 콜이 3개예요.
  - 측정값은 sched_yield 초당 약 32만 회, getrusage 약 65만 회예요.
- 원인이 아닌 것으로 확인된 것:
  - FEX 관리 비용 (약 2%)
  - Wine 동기화 방식
  - 페이지 폴트와 스왑
  - Turnip 드라이버
  - 시간 조회

### 동작
같은 스레드가 200µs 안에 다시 `sched_yield`하면, 바로 넘기지 않고 `YF_SLEEP_US`(기본 50µs)만큼 잠들어요. 명령줄에 `Cyberpunk2077.exe`가 들어간 프로세스(또는 `YF_TARGET`에 적은 이름)에서만 동작해요.

### 쓰는 법 (DroidDeck)
1. `yieldfix.sh`와 `libyieldfix.so`를 SD카드의 `Android/data/com.antutu.benchmark.full/files/steam/` 폴더에 복사해요. 로그 경로로 보면 게스트 안에서는 `/mnt/droiddeck-sd/`로 보이는 곳이에요.
2. 게임의 Steam 실행 옵션에 넣어요:
   ```
   sh /mnt/droiddeck-sd/yieldfix.sh %command%
   ```
3. 필요하면 옵션을 바꿔요.
   - 잠드는 시간 바꾸기: `YF_SLEEP_US=20 sh /mnt/droiddeck-sd/yieldfix.sh %command%`
   - 한 번만 끄기: `YF=0`
   - 다른 게임에 적용: `YF_TARGET=이름.exe`

SD카드가 noexec라서, 스크립트가 라이브러리를 `/tmp`(안 되면 `$HOME`)로 복사해서 불러와요.

### 지금까지 결과
- 게임 중 코어 사용률이 92~100%에서 56~64%로 내려갔어요.
- Prime 코어가 3.8GHz를 유지했고, 발열이 줄었고, 플레이가 쾌적해졌어요.
- **부작용:** 빠르게 운전하면 월드 로딩이 늦어서 바닥이 없거나, 안 보이는 물체에 부딪힐 수 있어요. 스트리밍 스레드도 늦게 깨어나기 때문으로 보여요. `YF_SLEEP_US`를 20이나 10으로 줄이면, CPU 절약을 조금 내주는 대신 스트리밍이 나아질 수 있어요.
- 리눅스는 sleep을 timer slack(기본 50µs) 단위로 늘려서 처리해요. 그래서 작은 값은 실제로 더 오래 잘 수 있어요. 라이브러리에서 `prctl(PR_SET_TIMERSLACK, 1)`을 부르면 작은 값도 정확해져요. 이건 지금 바이너리에는 들어 있지 않아요.

`libyieldfix.so`의 소스는 아직 이 레포에 없어요.
