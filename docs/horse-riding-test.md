# 말 타기 테스트 절차

## 0. 준비
1. `rojo serve` 후 Studio Rojo 플러그인에서 Connect. `ServerScriptService`에 HorseRiding, HorseRidingService, HorseRidingTests,
   `StarterPlayerScripts`에 HorseRiderController, HorseAnimator가 보이면 된다.
2. 출력(Output) 창을 연다.

## 1. 자동 테스트 (약 1분)
1. `ServerScriptService` 선택 → Properties 아래 Attributes에서 `+` → 이름 `RunHorseTests`, 종류 Boolean, 체크.
2. Play(F5). 캐릭터가 말 5마리를 차례로 타고 내리며 `[HorseTest] PASS/FAIL` 줄이 찍힌다.
3. 마지막 줄 `[HorseTest] 끝: N 통과, M 실패`를 확인한다. FAIL 줄을 그대로 알려 주면 된다.
4. 뒷자리까지 보려면: 테스트 탭 → 클라이언트 및 서버 → 플레이어 2 → 시작.
5. 끝나면 `RunHorseTests` 체크를 끈다(켜 두면 Play할 때마다 돈다).

자동 테스트가 보는 것: 탑승, 고정 해제, 네트워크 소유권이 운전자에게 갔는지, 꾸미기 색 적용(타기 전/타는 중),
하차, 다시 고정, 똑바로 서는지, "마구간으로"가 원래 칸으로 돌려놓는지, (2명일 때) 뒷자리 탑승/하차.
자동 테스트가 못 보는 것: 실제 키 입력으로 달리는 느낌, 애니메이션 모양, 소리, 물/경계. 아래 수동 항목으로 확인한다.

## 2. 수동 테스트 (말마다: 초코, 구름, 밤이, 눈송이, 고구마)
| # | 할 일 | 기대 결과 |
|---|---|---|
| 1 | 말 옆에 선다 | "타기 [E]"와 "꾸미기 [C]" 두 프롬프트가 겹치지 않게 보인다 |
| 2 | E | 말 등에 앉고 말 우는 소리(Mount). 화면 아래 HUD에 말 이름 |
| 3 | W 유지 | 서쪽으로 칸 문을 지나 나간다. HUD가 걷기→속보, 다리가 움직이고 발굽 소리 |
| 4 | W + Shift | 질주. 발굽 소리가 Gallop으로 바뀌고 초코는 발굽 먼지 |
| 5 | Ctrl 누르고 W | 걷기 속도로 고정(다시 Ctrl로 해제) |
| 6 | A/D | 제자리/달리며 회전. 질주 중엔 더 크게 돈다 |
| 7 | S | 천천히 뒤로 |
| 8 | Space | 말이 점프한다. **캐릭터가 말에서 떨어지면 실패** |
| 9 | 언덕 오르내리기 | 말이 경사를 따라 기울고 공중에 뜨거나 파묻히지 않는다 |
| 10 | 호수로 달린다 | 얕은 물가에서 느려지고, 깊은 곳 앞에서 멈춘다 |
| 11 | 분지 가장자리로 달린다 | 경계 근처에서 멈춘다 |
| 12 | 나무로 달린다 | 지금은 통과한다(나무 충돌은 작업 ③) |
| 13 | X | 말 옆에 내려서고 말은 그 자리에 똑바로 선다 |
| 14 | 다시 E로 타고 Z | 내려지고 말이 원래 칸으로 돌아간다 |
| 15 | 타고 있는 동안 C | 꾸미기 메뉴가 열리고 색이 바로 바뀐다 |

모바일(에뮬레이터: 테스트 탭 → 기기)에서: 썸스틱으로 이동, 점프 버튼으로 말 점프, HUD의 질주/걷기/내리기/마구간으로 버튼.
게임패드: 왼쪽 스틱 이동, A 점프, R2 또는 L3 질주, L1 걷기, B 내리기.

## 3. 숫자 조정 위치
`src/shared/HorseConfig.luau`
- 탄 사람이 떠 보이거나 파묻히면: `Rigs.<종류>.driverSeat` / `passengerSeat`의 Y
- 속도: `Speed`, 회전: `TurnRateStand` / `TurnRateGallop`, 점프: `JumpVelocity`
- 다리 흔들림이 반대로 보이면: `legs.<다리>.flexSign` 부호
- 승마 자세 애니메이션: `RideAnimationId`에 본인 애니메이션 ID(rbxassetid://...)
