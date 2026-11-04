// Adam Arena 0.6.7 — native-game API experiment for macOS 2.5.
// Requires redscript 0.5.32. No custom native declarations or Windows plugins.

// Visible probes independent of the player-attachment callback and HUD messages.
@wrapMethod(SingleplayerMenuGameController)
protected cb func OnInitialize() -> Bool {
  wrappedMethod();
  inkTextRef.SetText(this.m_versionTextRef, "아담 투기장 0.6.7 스크립트 로드");
}

@wrapMethod(PauseMenuGameController)
protected cb func OnInitialize() -> Bool {
  let player: ref<PlayerPuppet>;
  wrappedMethod();
  player = this.GetPlayerControlledObject() as PlayerPuppet;
  if IsDefined(player) && !IsDefined(player.adamArenaController) {
    player.adamArenaController = new AdamArenaController();
    player.adamArenaController.Start(player);
  };
  if IsDefined(this.m_buttonHintsController) {
    if IsDefined(player) && IsDefined(player.adamArenaController) {
      this.m_buttonHintsController.AddButtonHint(n"back", "악몽 리허설 0.6.7 · 상태 확인 메뉴 추가됨");
    } else {
      this.m_buttonHintsController.AddButtonHint(n"back", "아담 0.6.7: 플레이어 초기화 대기");
    };
  };
}

@addField(PauseMenuGameController)
private let adamDiagnosticsToken: ref<inkGameNotificationToken>;

@wrapMethod(PauseMenuGameController)
private func PopulateMenuItemList() -> Void {
  wrappedMethod();
  this.AddMenuItem("악몽 리허설 상태 확인", n"AdamDreamDiagnostics");
  this.m_menuListController.Refresh();
}

@wrapMethod(PauseMenuGameController)
protected cb func OnMenuItemActivated(index: Int32, target: ref<ListItemController>) -> Bool {
  let data: ref<PauseMenuListItemData> = target.GetData() as PauseMenuListItemData;
  let player: ref<PlayerPuppet>;
  if IsDefined(data) && Equals(data.eventName, n"AdamDreamDiagnostics") {
    player = this.GetPlayerControlledObject() as PlayerPuppet;
    if IsDefined(player) && IsDefined(player.adamArenaController) && !IsDefined(this.adamDiagnosticsToken) {
      this.adamDiagnosticsToken = GenericMessageNotification.Show(this, "악몽 리허설 0.6.7 — 상태", player.adamArenaController.Status() + "\n\n" + player.adamArenaController.BedDiagnostics(), GenericMessageNotificationType.Confirm);
      this.adamDiagnosticsToken.RegisterListener(this, n"OnAdamDiagnosticsClosed");
    };
    return true;
  };
  return wrappedMethod(index, target);
}

@addMethod(PauseMenuGameController)
protected cb func OnAdamDiagnosticsClosed(data: ref<inkGameNotificationData>) -> Bool {
  this.adamDiagnosticsToken = null;
}

@addField(PlayerPuppet)
public let adamArenaController: ref<AdamArenaController>;

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  wrappedMethod();
  // This experiment targets single-player V. Peer ownership is not a reliable
  // initialization gate in a single-player session.
  if !this.IsReplacer() {
    if IsDefined(this.adamArenaController) {
      this.adamArenaController.Stop();
    };
    this.adamArenaController = new AdamArenaController();
    this.adamArenaController.Start(this);
  };
}

// Use the player's existing ToggleWalk event route; preserve the original handler.
@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
  if !this.IsReplacer() {
    if !IsDefined(this.adamArenaController) {
      this.adamArenaController = new AdamArenaController();
      this.adamArenaController.Start(this);
    };
    if this.adamArenaController.HandleBedChoiceAction(action, consumer) {
      return true;
    };
    if Equals(ListenerAction.GetName(action), n"ToggleWalk") && this.adamArenaController.HandleDreamInput(action) {
      ListenerActionConsumer.ConsumeSingleAction(consumer);
      return true;
    };
  };
  return wrappedMethod(action, consumer);
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  if IsDefined(this.adamArenaController) {
    this.adamArenaController.Stop();
    this.adamArenaController = null;
  };
  wrappedMethod();
}

// Only consume our ticket. All ordinary police spawn results keep their handler.
@wrapMethod(PreventionSpawnSystem)
protected final func SpawnRequestFinished(requestResult: SpawnRequestResult) -> Void {
  let player: ref<PlayerPuppet> = GetMainPlayer(GetGameInstance());
  if IsDefined(player) && IsDefined(player.adamArenaController) {
    if player.adamArenaController.ReceiveSpawn(requestResult) {
      return;
    };
  };
  wrappedMethod(requestResult);
}

public class AdamArenaTick extends DelayCallback {
  public let controller: wref<AdamArenaController>;

  public func Call() -> Void {
    if IsDefined(this.controller) {
      this.controller.Tick();
    };
  }
}

public class AdamArenaController extends IScriptable {
  private let player: wref<PlayerPuppet>;
  private let running: Bool;
  private let timer: DelayID;
  private let tickCount: Int32;
  private let inputEvents: Int32;
  private let inRoom: Bool;
  private let preparing: Bool;
  private let arriving: Bool;
  private let arrivalTicks: Int32;
  private let prepareTicks: Int32;
  private let waking: Bool;
  private let wakeTicks: Int32;
  private let defeatPending: Bool;
  private let transitionProtected: Bool;
  private let savedHealth: Float;
  private let savedStamina: Float;
  private let healthListener: ref<AdamDreamHealthListener>;
  private let carryApplied: Bool;
  private let lastBedSnapshot: String;
  private let bedSelection: Int32;
  private let bedLaunchPending: Bool;
  private let bedConfirmCapture: Int32;
  private let bedSleepBypass: Int32;
  private let returnPosition: Vector4;
  private let returnOrientation: EulerAngles;
  private let roomPosition: Vector4;
  private let arenaTransform: WorldTransform;
  private let bossRecord: TweakDBID;
  private let pending: Bool;
  private let ticket: Uint32;
  private let pendingTicks: Int32;
  private let cancelledTickets: array<Uint32>;
  private let boss: wref<ScriptedPuppet>;
  private let bossID: EntityID;
  private let hasBoss: Bool;
  private let victoryShown: Bool;

  public final func Start(player: ref<PlayerPuppet>) -> Void {
    this.player = player;
    this.running = true;
    player.RegisterInputListener(player, n"Choice1");
    player.RegisterInputListener(player, n"ChoiceApply");
    player.RegisterInputListener(player, n"Choice1_Release");
    player.RegisterInputListener(player, n"Choice1_Hold");
    player.RegisterInputListener(player, n"ChoiceScrollUp");
    player.RegisterInputListener(player, n"ChoiceScrollDown");
    this.Schedule();
  }

  public final func Stop() -> Void {
    this.running = false;
    if IsDefined(this.player) {
      GameInstance.GetDelaySystem(this.player.GetGame()).CancelCallback(this.timer);
      this.Cleanup();
      this.ReleaseDreamProtection();
      this.player.UnregisterInputListener(this.player, n"Choice1");
      this.player.UnregisterInputListener(this.player, n"ChoiceApply");
      this.player.UnregisterInputListener(this.player, n"Choice1_Release");
      this.player.UnregisterInputListener(this.player, n"Choice1_Hold");
      this.player.UnregisterInputListener(this.player, n"ChoiceScrollUp");
      this.player.UnregisterInputListener(this.player, n"ChoiceScrollDown");
      this.inRoom = false;
    };
  }

  public final func HandleDreamInput(action: ListenerAction) -> Bool {
    this.inputEvents += 1;
    if this.inRoom {
      if ListenerAction.IsButtonJustPressed(action) && !this.waking {
        if this.victoryShown {
          this.ReturnHome("악몽 리허설 완료. 스매셔는 꿈에 남겨두고 눈을 떴다.");
        } else {
          this.ReturnHome("악몽 리허설 중단. 침대 곁에서 눈을 떴다.");
        };
      };
      return true;
    };
    return false;
  }

  public final func BedMenuVisible() -> Bool {
    return !this.inRoom && !this.bedLaunchPending && this.bedSleepBypass <= 0 && AdamDreamBedChoices.HasSleepChoice(this.player);
  }

  public final func BedSelection() -> Int32 {
    return this.bedSelection;
  }

  public final func ChooseBedOption(index: Int32) -> Void {
    this.bedSelection = index;
  }

  public final func ConfirmBedOption() -> Bool {
    if this.bedConfirmCapture > 0 {
      return true;
    };
    if !this.player.adamBedPickerDrawn || !this.BedMenuVisible() {
      return false;
    };
    if this.bedSelection == 0 {
      // Keep the real sleep action. The original engine confirms its existing row.
      this.bedSleepBypass = 4;
      return false;
    };
    this.bedConfirmCapture = 4;
    this.bedLaunchPending = true;
    return true;
  }

  public final func HandleBedChoiceAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let name: CName = ListenerAction.GetName(action);
    let confirm: Bool = Equals(name, n"Choice1") || Equals(name, n"ChoiceApply") || Equals(name, n"Choice1_Release") || Equals(name, n"Choice1_Hold");
    if confirm && this.bedConfirmCapture > 0 {
      ListenerActionConsumer.ConsumeSingleAction(consumer);
      return true;
    };
    if !this.player.adamBedPickerDrawn || !this.BedMenuVisible() {
      return false;
    };
    if ListenerAction.IsButtonJustPressed(action) {
      if Equals(name, n"ChoiceScrollUp") {
        this.ChooseBedOption(0);
        AdamDreamBedChoices.RefreshPickers(this.player);
        ListenerActionConsumer.ConsumeSingleAction(consumer);
        return true;
      };
      if Equals(name, n"ChoiceScrollDown") {
        this.ChooseBedOption(1);
        AdamDreamBedChoices.RefreshPickers(this.player);
        ListenerActionConsumer.ConsumeSingleAction(consumer);
        return true;
      };
      if confirm && this.ConfirmBedOption() {
        ListenerActionConsumer.ConsumeSingleAction(consumer);
        return true;
      };
    };
    return false;
  }

  public final func IsDreamProtected() -> Bool {
    return this.inRoom;
  }

  public final func MarkDreamDefeat() -> Void {
    if this.inRoom && !this.waking {
      this.defeatPending = true;
    };
  }

  private final func Schedule() -> Void {
    let callback: ref<AdamArenaTick> = new AdamArenaTick();
    callback.controller = this;
    this.timer = GameInstance.GetDelaySystem(this.player.GetGame()).DelayCallback(callback, 0.50, false);
  }

  public final func Tick() -> Void {
    let position: Vector4;
    let health: Float;
    if !this.running || !IsDefined(this.player) {
      return;
    };
    this.Schedule();
    this.tickCount += 1;
    if this.tickCount == 1 || this.tickCount % 4 == 0 {
      AdamCapacityRules.RefreshInstalledCapacity(this.player);
    };
    this.RefreshCapacityPenalty();
    AdamCapacityRules.UpdateWalking(this.player);
    AdamDreamBedChoices.RefreshPickers(this.player);
    if AdamDreamBedChoices.HasAnyChoice(this.player) {
      this.lastBedSnapshot = AdamDreamBedChoices.DebugState(this.player);
    };
    if this.tickCount == 4 {
      this.Message("악몽 리허설 0.6.7 실행 중. 침대에서 잠자기 / 아담과 싸우기 선택.");
    };
    if this.bedConfirmCapture > 0 { this.bedConfirmCapture -= 1; };
    if this.bedSleepBypass > 0 { this.bedSleepBypass -= 1; };
    if this.bedLaunchPending {
      this.bedLaunchPending = false;
      if AdamDreamBedChoices.HasSleepChoice(this.player) && this.CanStart() {
        this.EnterRoom();
      } else {
        this.Message("침대 선택이 취소됐습니다. 침대를 다시 바라보고 선택하세요.");
      };
      // Teleport changes the world asynchronously. Do not run any destination
      // boundary checks in the same callback that submits the teleport.
      return;
    };
    if !this.inRoom {
      return;
    };
    if this.waking {
      this.wakeTicks += 1;
      if this.wakeTicks >= 4 {
        this.ReleaseDreamProtection();
        this.inRoom = false;
        this.waking = false;
      };
      return;
    };
    health = GameInstance.GetStatPoolsSystem(this.player.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(this.player.GetEntityID()), gamedataStatPoolType.Health, true);
    if this.defeatPending || this.player.IsDead() || health <= 2.05 {
      this.ReturnHome("치명상은 꿈이었다. 숨을 몰아쉬며 침대 곁에서 눈을 떴다.");
      return;
    };
    position = this.player.GetWorldPosition();
    if this.arriving {
      this.arrivalTicks += 1;
      switch AdamDreamTravelRules.ArrivalState(Vector4.DistanceSquared(position, this.roomPosition), AbsF(position.Z - this.roomPosition.Z), this.arrivalTicks) {
        case 1:
          this.arriving = false;
          this.prepareTicks = 0;
          this.Message("악몽 전투실 도착. 바닥과 스매셔를 준비하는 중…");
          break;
        case 2:
          this.ReturnHome("악몽 전투실 이동을 완료하지 못해 침대 곁으로 돌아갑니다.");
          break;
      };
      return;
    };
    if position.Z < this.roomPosition.Z - 5.00 || Vector4.Distance(position, this.roomPosition) > 120.00 {
      this.ReturnHome("꿈의 경계를 벗어났다. 침대 곁에서 눈을 떴다.");
      return;
    };
    if this.preparing {
      this.prepareTicks += 1;
      if this.prepareTicks >= 8 {
        if this.SelectArena() {
          this.preparing = false;
        } else {
          if this.prepareTicks >= 30 {
            this.ReturnHome("악몽 전투실을 준비하지 못해 잠에서 깨어났습니다.");
          };
        };
      };
      return;
    };
    if this.pending {
      this.pendingTicks += 1;
      if this.pendingTicks >= 40 {
        this.ReturnHome("트레이닝 대상의 응답이 없어 잠에서 깨어났습니다.");
      };
      return;
    };
    if this.hasBoss && !this.victoryShown {
      if !IsDefined(this.boss) {
        this.ReturnHome("트레이닝 대상이 사라져 잠에서 깨어났습니다.");
      } else {
        if this.boss.IsDead() || ScriptedPuppet.IsDefeated(this.boss) {
          this.victoryShown = true;
          this.SetTransitionProtection(true);
          this.Message("스매셔 격파. G — 트레이닝 종료 · 눈뜨기");
        };
      };
    };
  }

  private final func GroundPosition(position: Vector4, out ground: Vector4) -> Bool {
    let hit: TraceResult;
    let hitPosition: Vector3;
    let start: Vector4 = position;
    let end: Vector4 = position;
    start.Z += 1.00;
    end.Z -= 4.00;
    if !GameInstance.GetSpatialQueriesSystem(this.player.GetGame()).SyncRaycastByCollisionGroup(start, end, n"Static", hit, true, false) {
      return false;
    };
    // A vertical ray must preserve the intended horizontal destination.
    hitPosition = hit.position;
    ground = position;
    ground.W = 1.00;
    ground.Z = hitPosition.Z + 0.15;
    return true;
  }

  private final func SelectArena() -> Bool {
    let ground: Vector4;
    let bossPosition: Vector4;
    let direction: Vector4 = this.player.GetWorldForward();
    direction.Z = 0.00;
    direction = Vector4.Normalize(direction);
    bossPosition = this.roomPosition + direction * 6.00;
    if !this.GroundPosition(bossPosition, ground) {
      return false;
    };
    WorldTransform.SetPosition(this.arenaTransform, ground);
    WorldTransform.SetOrientation(this.arenaTransform, this.player.GetWorldOrientation());
    this.pending = true;
    this.pendingTicks = 0;
    this.ticket = GameInstance.GetPreventionSpawnSystem(this.player.GetGame()).RequestUnitSpawn(this.bossRecord, this.arenaTransform);
    this.Message("악몽 리허설 시작. 아담 스매셔를 불러오는 중…");
    return true;
  }

  private final func RoomFacing() -> EulerAngles {
    let orientation: EulerAngles;
    orientation.Yaw = 85.67997;
    return orientation;
  }

  private final func EnterRoom() -> Void {
    // No fallback to the easier generic Character.Smasher record.
    this.bossRecord = t"Character.q116_boss_smasher";
    if !IsDefined(TweakDBInterface.GetCharacterRecord(this.bossRecord)) {
      this.Message("이동 취소: 보스전용 Character.q116_boss_smasher 레코드가 없음");
      return;
    };
    this.returnPosition = this.player.GetWorldPosition();
    this.returnOrientation = Quaternion.ToEulerAngles(this.player.GetWorldOrientation());
    // User-confirmed boss-room position, matching P/T readings in 0.4.3.
    this.roomPosition = new Vector4(-1398.331787, 144.787277, -26.648010, 1.00);
    this.savedHealth = GameInstance.GetStatPoolsSystem(this.player.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(this.player.GetEntityID()), gamedataStatPoolType.Health, true);
    this.savedStamina = GameInstance.GetStatPoolsSystem(this.player.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(this.player.GetEntityID()), gamedataStatPoolType.Stamina, true);
    if this.savedHealth <= 2.05 {
      this.Message("체력이 너무 낮습니다. 회복한 뒤 침대에서 다시 시도하세요.");
      return;
    };
    if !GameInstance.GetGodModeSystem(this.player.GetGame()).AddGodMode(this.player.GetEntityID(), gameGodModeType.Immortal, n"AdamDreamTraining") {
      this.Message("사망 방지 보호를 설정하지 못해 트레이닝을 취소했습니다.");
      return;
    };
    this.SetTransitionProtection(true);
    SaveLocksManager.RequestSaveLockAdd(this.player.GetGame(), n"AdamDreamTraining");
    this.healthListener = new AdamDreamHealthListener();
    this.healthListener.controller = this;
    this.inRoom = true;
    GameInstance.GetStatPoolsSystem(this.player.GetGame()).RequestRegisteringListener(Cast<StatsObjectID>(this.player.GetEntityID()), gamedataStatPoolType.Health, this.healthListener);
    this.preparing = true;
    this.arriving = true;
    this.arrivalTicks = 0;
    this.prepareTicks = 0;
    this.waking = false;
    this.defeatPending = false;
    this.victoryShown = false;
    GameInstance.GetTeleportationFacility(this.player.GetGame()).Teleport(this.player, this.roomPosition, this.RoomFacing());
    this.Message("눈을 감으면 다시 아라사카. 악몽 리허설 — 아담 스매셔");
  }

  private final func ReturnHome(text: String) -> Void {
    if !this.inRoom || this.waking {
      return;
    };
    this.waking = true;
    this.wakeTicks = 0;
    this.preparing = false;
    this.arriving = false;
    this.SetTransitionProtection(true);
    this.Cleanup();
    this.player.GetPuppetPS().SetIsDead(false);
    GameInstance.GetTeleportationFacility(this.player.GetGame()).Teleport(this.player, this.returnPosition, this.returnOrientation);
    GameInstance.GetStatPoolsSystem(this.player.GetGame()).RequestSettingStatPoolValue(Cast<StatsObjectID>(this.player.GetEntityID()), gamedataStatPoolType.Health, this.savedHealth, this.player, true);
    GameInstance.GetStatPoolsSystem(this.player.GetGame()).RequestSettingStatPoolValue(Cast<StatsObjectID>(this.player.GetEntityID()), gamedataStatPoolType.Stamina, this.savedStamina, this.player, true);
    this.Message(text);
  }

  private final func SetTransitionProtection(enabled: Bool) -> Void {
    let gods: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.player.GetGame());
    if enabled && !this.transitionProtected {
      this.transitionProtected = gods.AddGodMode(this.player.GetEntityID(), gameGodModeType.Invulnerable, n"AdamDreamTransition");
    } else {
      if !enabled && this.transitionProtected {
        gods.RemoveGodMode(this.player.GetEntityID(), gameGodModeType.Invulnerable, n"AdamDreamTransition");
        this.transitionProtected = false;
      };
    };
  }

  private final func ReleaseDreamProtection() -> Void {
    let gods: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.player.GetGame());
    gods.RemoveGodMode(this.player.GetEntityID(), gameGodModeType.Immortal, n"AdamDreamTraining");
    this.SetTransitionProtection(false);
    SaveLocksManager.RequestSaveLockRemove(this.player.GetGame(), n"AdamDreamTraining");
    if IsDefined(this.healthListener) {
      GameInstance.GetStatPoolsSystem(this.player.GetGame()).RequestUnregisteringListener(Cast<StatsObjectID>(this.player.GetEntityID()), gamedataStatPoolType.Health, this.healthListener);
      this.healthListener = null;
    };
  }

  public final func RefreshCapacityPenalty() -> Void {
    let changed: Bool;
    let board: ref<IBlackboard>;
    let capacity: Int32;
    if !IsDefined(this.player) {
      return;
    };
    changed = NotEquals(this.carryApplied, AdamCapacityRules.IsOverloaded(this.player));
    this.carryApplied = AdamCapacityRules.IsOverloaded(this.player);
    capacity = Cast<Int32>(AdamCapacityRules.EffectiveCarryCapacity(this.player));
    board = GameInstance.GetBlackboardSystem(this.player.GetGame()).Get(GetAllBlackboardDefs().UI_PlayerStats);
    if board.GetInt(GetAllBlackboardDefs().UI_PlayerStats.weightMax) != capacity || changed {
      board.SetInt(GetAllBlackboardDefs().UI_PlayerStats.weightMax, capacity, true);
    };
    this.player.EvaluateEncumbrance();
  }

  public final func BedDiagnostics() -> String {
    return this.lastBedSnapshot + "\n패널 생성=" + ToString(this.player.adamBedPickerCreated)
      + " 표시=" + ToString(this.player.adamBedPickerDrawn)
      + "\nUI 갱신 " + IntToString(this.player.adamBedHookEvents) + " | 화면 연결 " + IntToString(this.player.adamBedHosts) + " | " + this.player.adamBedCreationStage;
  }

  public final func Status() -> String {
    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(this.player.GetGame());
    let id: StatsObjectID = Cast<StatsObjectID>(this.player.GetEntityID());
    let allocated: Float = stats.GetStatValue(id, gamedataStatType.HumanityAllocated);
    let maximum: Float = AdamCapacityRules.LegalMaximum(this.player);
    let displayedMaximum: Float = stats.GetStatValue(id, gamedataStatType.HumanityTotalMaxValue);
    let carry: Float = AdamCapacityRules.EffectiveCarryCapacity(this.player);
    let over: Float = stats.GetStatValue(id, gamedataStatType.HumanityOverallocated);
    let allowed: Float = stats.GetStatValue(id, gamedataStatType.HumanityOverallocationPossible);
    let status: String = "사이버웨어 " + IntToString(Cast<Int32>(allocated)) + "/" + IntToString(Cast<Int32>(maximum)) + " (실제 허용 한도)"
      + "\n게임 표시 한도 " + FloatToString(displayedMaximum) + " | 적용 운반 " + FloatToString(carry)
      + " (기본 " + FloatToString(stats.GetStatValue(id, gamedataStatType.CarryCapacity)) + ")";
    if this.inRoom {
      status += this.waking ? " | 깨어나는 중" : " | 악몽 리허설 / G: 종료";
    };
    status += "\n사용 초과분 " + IntToString(Cast<Int32>(over)) + " | 게임 임시 허용분 " + IntToString(Cast<Int32>(allowed))
      + "\n보유 특전 허용분 " + FloatToString(AdamCapacityRules.PerkAllowance(this.player)) + " | 장착합 " + FloatToString(this.player.adamInstalledCapacity);
    if AdamCapacityRules.IsOverloaded(this.player) {
      return status + " | 초과: 이동·사격 소모 3배";
    };
    return status + " | 정상";
  }

  private final func CanStart() -> Bool {
    return !this.player.IsInCombat()
      && !this.player.IsReplacer()
      && !GameInstance.GetWorkspotSystem(this.player.GetGame()).IsActorInWorkspot(this.player)
      && !GameInstance.GetBlackboardSystem(this.player.GetGame()).Get(GetAllBlackboardDefs().UI_System).GetBool(GetAllBlackboardDefs().UI_System.IsInMenu)
      && !this.player.GetPlayerStateMachineBlackboard().GetBool(GetAllBlackboardDefs().PlayerStateMachine.MountedToVehicle);
  }

  public final func ReceiveSpawn(result: SpawnRequestResult) -> Bool {
    let i: Int32;
    let command: ref<AIInjectCombatThreatCommand>;
    let references: array<CName>;
    // A cancelled asynchronous request may still complete later in this session.
    if ArrayContains(this.cancelledTickets, result.requestID) {
      ArrayRemove(this.cancelledTickets, result.requestID);
      i = 0;
      while i < ArraySize(result.spawnedObjects) {
        if IsDefined(result.spawnedObjects[i]) {
          GameInstance.GetPreventionSpawnSystem(this.player.GetGame()).RequestDespawn(result.spawnedObjects[i].GetEntityID());
        };
        i += 1;
      };
      return true;
    };
    if !this.pending || result.requestID != this.ticket {
      return false;
    };
    this.pending = false;
    i = 0;
    while i < ArraySize(result.spawnedObjects) {
      if !IsDefined(this.boss) {
        this.boss = result.spawnedObjects[i] as ScriptedPuppet;
      };
      i += 1;
    };
    if !result.success || !IsDefined(this.boss) {
      // Despawn any partial result belonging to our failed request.
      i = 0;
      while i < ArraySize(result.spawnedObjects) {
        if IsDefined(result.spawnedObjects[i]) {
          GameInstance.GetPreventionSpawnSystem(this.player.GetGame()).RequestDespawn(result.spawnedObjects[i].GetEntityID());
        };
        i += 1;
      };
      this.boss = null;
      this.ReturnHome("아담 소환 실패. 악몽 리허설을 마치고 눈을 떴다.");
      return true;
    };
    this.hasBoss = true;
    this.bossID = this.boss.GetEntityID();
    this.victoryShown = false;
    GameObject.ChangeAttitudeToHostile(this.boss, this.player);
    command = new AIInjectCombatThreatCommand();
    command.targetPuppetRef = CreateEntityReference("#player", references);
    command.duration = 3600.00;
    AIComponent.SendCommand(this.boss, command);
    this.SetTransitionProtection(false);
    this.Message("악몽 리허설 — 아담 스매셔. 패배하면 잠에서 깨어납니다. G로 트레이닝 중단");
    return true;
  }

  private final func Cleanup() -> Void {
    let system: ref<PreventionSpawnSystem> = GameInstance.GetPreventionSpawnSystem(this.player.GetGame());
    if this.pending {
      ArrayPush(this.cancelledTickets, this.ticket);
      system.CancelSpawnRequest(this.ticket);
      this.pending = false;
    };
    if this.hasBoss {
      system.RequestDespawn(this.bossID);
      this.hasBoss = false;
      this.boss = null;
    };
  }

  private final func Message(text: String) -> Void {
    let message: SimpleScreenMessage;
    message.isShown = true;
    message.isInstant = true;
    message.duration = 6.00;
    message.type = SimpleMessageType.Neutral;
    message.message = text;
    GameInstance.GetBlackboardSystem(this.player.GetGame()).Get(GetAllBlackboardDefs().UI_Notifications).SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(message), true);
  }
}


// Capacity penalties are computed from live stats; no permanent stat modifiers.
@addField(PlayerPuppet)
public let adamRespecInProgress: Bool;

@addField(PlayerPuppet)
public let adamStaminaCostScope: Int32;

@addField(PlayerPuppet)
public let adamInstalledCapacity: Float;

public abstract class AdamCapacityRules {
  public final static func CapacityLimit(engineMaximum: Float, engineAllowance: Float, legalPerkAllowance: Float) -> Float {
    // The UI's maximum can expand to preserve already installed cyberware.
    // The native ripperdoc derives its base as total minus overallocation.
    // Restore only the allowance granted by a currently owned perk.
    return MaxF(0.00, engineMaximum - engineAllowance) + MaxF(0.00, legalPerkAllowance);
  }

  public final static func HasCapacityDeficit(allocated: Float, maximum: Float, installed: Float) -> Bool {
    return allocated > maximum + 0.01 || installed > maximum + 0.01;
  }

  public final static func PerkAllowance(player: ref<PlayerPuppet>) -> Float {
    let data: ref<PlayerDevelopmentData> = PlayerDevelopmentSystem.GetData(player);
    if IsDefined(data) && data.IsNewPerkBought(gamedataNewPerkType.Tech_Master_Perk_3) > 0 {
      return TweakDBInterface.GetFloat(t"NewPerks.Tech_Master_Perk_3.amountOfCapacityGivenForRipperdocUI", 50.00);
    };
    return 0.00;
  }

  public final static func LegalMaximum(player: ref<PlayerPuppet>) -> Float {
    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(player.GetGame());
    let id: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());
    return AdamCapacityRules.CapacityLimit(
      stats.GetStatValue(id, gamedataStatType.HumanityTotalMaxValue),
      stats.GetStatValue(id, gamedataStatType.HumanityOverallocationPossible),
      AdamCapacityRules.PerkAllowance(player)
    );
  }

  public final static func RefreshInstalledCapacity(player: ref<PlayerPuppet>) -> Void {
    let items: array<wref<gameItemData>>;
    let requirements: array<SItemStackRequirementData>;
    let data: ref<EquipmentSystemPlayerData>;
    let i: Int32;
    let j: Int32;
    let total: Float;
    if !IsDefined(player) || player.IsReplacer() { return; };
    data = EquipmentSystem.GetData(player);
    if !IsDefined(data) { return; };
    GameInstance.GetTransactionSystem(player.GetGame()).GetItemListByTag(player, n"Cyberware", items);
    i = 0;
    while i < ArraySize(items) {
      if data.IsEquipped(items[i].GetID()) {
        requirements = RPGManager.GetEquipRequirements(player, items[i]);
        j = 0;
        while j < ArraySize(requirements) {
          if Equals(requirements[j].statType, gamedataStatType.HumanityAvailable) {
            total += requirements[j].requiredValue;
            break;
          };
          j += 1;
        };
      };
      i += 1;
    };
    player.adamInstalledCapacity = total;
  }

  public final static func IsOverloaded(owner: ref<GameObject>) -> Bool {
    let player: ref<PlayerPuppet> = owner as PlayerPuppet;
    let stats: ref<StatsSystem>;
    let id: StatsObjectID;
    if !IsDefined(player) || player.IsReplacer() {
      return false;
    };
    if !IsDefined(PlayerDevelopmentSystem.GetData(player)) {
      return false;
    };
    stats = GameInstance.GetStatsSystem(player.GetGame());
    id = Cast<StatsObjectID>(player.GetEntityID());
    return AdamCapacityRules.HasCapacityDeficit(
      stats.GetStatValue(id, gamedataStatType.HumanityAllocated),
      AdamCapacityRules.LegalMaximum(player),
      player.adamInstalledCapacity
    );
  }

  public final static func EffectiveCarryCapacity(player: ref<PlayerPuppet>) -> Float {
    if AdamCapacityRules.IsOverloaded(player) { return 1.00; };
    return GameInstance.GetStatsSystem(player.GetGame()).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.CarryCapacity);
  }

  public final static func IsWalking(player: ref<PlayerPuppet>) -> Bool {
    let velocity: Vector4;
    if !IsDefined(player) || player.IsDead() || player.IsReplacer() {
      return false;
    };
    if player.GetPlayerStateMachineBlackboard().GetBool(GetAllBlackboardDefs().PlayerStateMachine.MountedToVehicle) {
      return false;
    };
    if GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UI_System).GetBool(GetAllBlackboardDefs().UI_System.IsInMenu) {
      return false;
    };
    if NotEquals(PlayerPuppet.GetCurrentHighLevelState(player), gamePSMHighLevel.SceneTier1) {
      return false;
    };
    velocity = player.GetVelocity();
    velocity.Z = 0.00;
    return Vector4.Length(velocity) > 0.10;
  }

  public final static func UpdateWalking(player: ref<PlayerPuppet>) -> Void {
    let velocity: Vector4;
    let speed: Float;
    if !AdamCapacityRules.IsOverloaded(player) || !AdamCapacityRules.IsWalking(player) {
      return;
    };
    velocity = player.GetVelocity();
    velocity.Z = 0.00;
    speed = MinF(Vector4.Length(velocity), 8.00);
    // Normal walking costs zero. Define a 1 point/m baseline, then apply x3.
    // Called every 0.5 simulation seconds. Bypass scoped action multipliers.
    GameInstance.GetStatPoolsSystem(player.GetGame()).RequestChangingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Stamina, -speed * 0.50 * 3.00, null, false, false);
  }

  public final static func RelabelResetButton(widget: ref<inkWidget>) -> Void {
    let text: ref<inkText> = widget as inkText;
    let compound: ref<inkCompoundWidget> = widget as inkCompoundWidget;
    let i: Int32;
    if IsDefined(text) {
      text.SetText("특전·특성 모두 초기화");
    };
    if IsDefined(compound) {
      i = 0;
      while i < compound.GetNumChildren() {
        AdamCapacityRules.RelabelResetButton(compound.GetWidgetByIndex(i));
        i += 1;
      };
    };
  }
}

// Reuse the game's reset button and its pointer callbacks. No startup reset.
@replaceMethod(NewPerksCategoriesGameController)
private final func ResolveResetAttributesButtonVisibility() -> Void {
  inkWidgetRef.SetVisible(this.m_resetAttributesButton, IsDefined(this.m_player));
  AdamCapacityRules.RelabelResetButton(inkWidgetRef.Get(this.m_resetAttributesButton));
}

@replaceMethod(NewPerksCategoriesGameController)
protected cb func OnResetAttributesButtonClick(evt: ref<inkPointerEvent>) -> Bool {
  if !evt.IsAction(n"click") && !evt.IsAction(n"tap") {
    return false;
  };
  if !IsDefined(this.m_player) || IsDefined(this.m_resetConfirmationToken) {
    return false;
  };
  if this.m_player.IsInCombat() {
    this.m_resetConfirmationToken = GenericMessageNotification.Show(this, "초기화 불가", "전투를 끝낸 뒤 다시 눌러 주세요.", GenericMessageNotificationType.Confirm);
    this.m_resetConfirmationToken.RegisterListener(this, n"OnResetFailed");
    return false;
  };
  this.m_resetConfirmationToken = GenericMessageNotification.Show(this, "특전·특성 모두 초기화", "특전과 특성에 사용한 포인트를 돌려받습니다. 각 특성은 3으로 돌아갑니다. 장착 사이버웨어는 유지합니다. 용량 초과 시 운반 용량 1, 이동·사격 스태미나 소모 3배, 달리기·점프 금지가 적용됩니다. 초기화할까요?", GenericMessageNotificationType.YesNo);
  this.m_resetConfirmationToken.RegisterListener(this, n"OnAdamResetConfirmed");
  return true;
}

@addMethod(NewPerksCategoriesGameController)
protected cb func OnAdamResetConfirmed(data: ref<inkGameNotificationData>) -> Bool {
  let result: ref<GenericMessageNotificationCloseData> = data as GenericMessageNotificationCloseData;
  this.m_resetConfirmationToken = null;
  if !IsDefined(result) || NotEquals(result.result, GenericMessageNotificationResult.Yes) || !IsDefined(this.m_player) {
    return false;
  };
  if this.m_player.IsInCombat() || this.m_player.adamRespecInProgress {
    return false;
  };
  // Synchronous, narrow guard: preserve cyberware only during this button action.
  this.m_player.adamRespecInProgress = true;
  PlayerDevelopmentSystem.GetData(this.m_player).ResetNewPerks();
  PlayerDevelopmentSystem.GetData(this.m_player).ResetAttributes();
  this.m_player.adamRespecInProgress = false;
  AdamCapacityRules.RefreshInstalledCapacity(this.m_player);
  if IsDefined(this.m_player.adamArenaController) {
    this.m_player.adamArenaController.RefreshCapacityPenalty();
  };
  this.QueueEvent(new PlayerDevUpdateDataEvent());
  this.ResolveResetAttributesButtonVisibility();
  this.PlaySound(n"Attributes", n"OnDone");
  this.PlayLibraryAnimation(n"panel_categories_reset_attributes");
  return true;
}

// Vanilla reset unequips perk-slot cyberware. Suppress only that reset side effect.
@wrapMethod(PlayerDevelopmentData)
private final func HandleRemovingTech_Central_Milestone_3(playerData: ref<EquipmentSystemPlayerData>) -> Void {
  let player: ref<PlayerPuppet> = this.m_owner as PlayerPuppet;
  if IsDefined(player) && player.adamRespecInProgress {
    return;
  };
  wrappedMethod(playerData);
}

@wrapMethod(EquipmentSystem)
public final static func RequestUnequipItem(owner: ref<GameObject>, equipmentArea: gamedataEquipmentArea, slotIndex: Int32) -> Void {
  let player: ref<PlayerPuppet> = owner as PlayerPuppet;
  if IsDefined(player) && player.adamRespecInProgress {
    if Equals(equipmentArea, gamedataEquipmentArea.MusculoskeletalSystemCW) || Equals(equipmentArea, gamedataEquipmentArea.HandsCW) || Equals(equipmentArea, gamedataEquipmentArea.IntegumentarySystemCW) {
      return;
    };
  };
  wrappedMethod(owner, equipmentArea, slotIndex);
}

// Multiply only stamina calls made inside locomotion/ranged shooting contexts.
@wrapMethod(PlayerStaminaHelpers)
public final static func ModifyStamina(player: ref<PlayerPuppet>, delta: Float, opt perc: Bool) -> Void {
  if IsDefined(player) && player.adamStaminaCostScope > 0 && delta < 0.00 && AdamCapacityRules.IsOverloaded(player) {
    delta *= 3.00;
  };
  wrappedMethod(player, delta, perc);
}

@wrapMethod(LocomotionEventsTransition)
protected final func ConsumeStaminaBasedOnLocomotionState(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) { player.adamStaminaCostScope += 1; };
  wrappedMethod(stateContext, scriptInterface);
  if IsDefined(player) { player.adamStaminaCostScope -= 1; };
}

@wrapMethod(ShootEvents)
protected final func ConsumeStamina(scriptInterface: ref<StateGameScriptInterface>, attackRecord: wref<Attack_Record>, staminaPenaltyMultiplier: Float, staminaFullChargePenaltyMultiplier: Float) -> Void {
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) { player.adamStaminaCostScope += 1; };
  wrappedMethod(scriptInterface, attackRecord, staminaPenaltyMultiplier, staminaFullChargePenaltyMultiplier);
  if IsDefined(player) { player.adamStaminaCostScope -= 1; };
}

// Includes Focused perk's deferred shooting cost on aiming exit.
@wrapMethod(AimingStateEvents)
protected func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) { player.adamStaminaCostScope += 1; };
  wrappedMethod(stateContext, scriptInterface);
  if IsDefined(player) { player.adamStaminaCostScope -= 1; };
}

@wrapMethod(StaminaTransition)
protected final const func ShouldRegenStamina(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if AdamCapacityRules.IsOverloaded(player) && AdamCapacityRules.IsWalking(player) {
    return false;
  };
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(CrouchDecisions)
protected const func ToSprint(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if AdamCapacityRules.IsOverloaded(scriptInterface.executionOwner) {
    return false;
  };
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(CrouchDecisions)
protected const func ToCrouchSprint(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if AdamCapacityRules.IsOverloaded(scriptInterface.executionOwner) {
    return false;
  };
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(SprintDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if AdamCapacityRules.IsOverloaded(scriptInterface.executionOwner) {
    return false;
  };
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(SprintDecisions)
protected const func ToStand(stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if AdamCapacityRules.IsOverloaded(scriptInterface.executionOwner) {
    return true;
  };
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(CrouchSprintDecisions)
protected const func ToCrouch(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if AdamCapacityRules.IsOverloaded(scriptInterface.executionOwner) {
    return true;
  };
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(JumpDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if AdamCapacityRules.IsOverloaded(scriptInterface.executionOwner) {
    return false;
  };
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(DoubleJumpDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if AdamCapacityRules.IsOverloaded(scriptInterface.executionOwner) {
    return false;
  };
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(ChargeJumpDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if AdamCapacityRules.IsOverloaded(scriptInterface.executionOwner) {
    return false;
  };
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(HoverJumpDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  if AdamCapacityRules.IsOverloaded(scriptInterface.executionOwner) {
    return false;
  };
  return wrappedMethod(stateContext, scriptInterface);
}


public abstract class AdamDreamTravelRules {
  // 0 = keep waiting, 1 = destination reached, 2 = timed out.
  public final static func ArrivalState(distanceSquared: Float, heightDifference: Float, ticks: Int32) -> Int32 {
    if distanceSquared <= 400.00 && heightDifference <= 8.00 { return 1; };
    if ticks >= 40 { return 2; };
    return 0;
  }
}

public abstract class AdamDreamBedChoices {
  public final static func RefreshPickers(player: ref<PlayerPuppet>) -> Void {
    let pickers: array<ref<AdamBedPicker>> = player.adamBedPickers;
    let i: Int32 = 0;
    while i < ArraySize(pickers) {
      if IsDefined(pickers[i]) { pickers[i].Refresh(); };
      i += 1;
    };
  }

  public final static func Caption() -> String {
    return "아담과 싸우기 — 악몽 리허설";
  }

  public final static func SingleSleepHub(data: DialogChoiceHubs) -> Int32 {
    let i: Int32 = 0;
    while i < ArraySize(data.choiceHubs) {
      if ArraySize(data.choiceHubs[i].choices) == 1 && AdamDreamBedChoices.DialogHasSleep(data.choiceHubs[i]) {
        return i;
      };
      i += 1;
    };
    return -1;
  }

  public final static func NativeBedView(source: DialogChoiceHubs, sleepHubIndex: Int32) -> DialogChoiceHubs {
    let result: DialogChoiceHubs;
    let hub: ListChoiceHubData;
    let dream: ListChoiceData;
    let choices: array<ListChoiceData>;
    let emptyCaption: InteractionChoiceCaption;
    let i: Int32 = 0;
    while i < ArraySize(source.choiceHubs) {
      hub = source.choiceHubs[i];
      if i == sleepHubIndex {
        // Build a new array instead of mutating the engine's one real sleep
        // action. The new row is rendered by the game's own dialog widgets.
        ArrayPush(choices, hub.choices[0]);
        dream = hub.choices[0];
        dream.localizedName = AdamDreamBedChoices.Caption();
        dream.inputActionName = n"None";
        dream.captionParts = emptyCaption;
        dream.timeProvider = null;
        ArrayPush(choices, dream);
        hub.choices = choices;
      };
      ArrayPush(result.choiceHubs, hub);
      i += 1;
    };
    return result;
  }

  public final static func FullCaption(name: String, parts: InteractionChoiceCaption) -> String {
    let textPart: ref<InteractionChoiceCaptionStringPart>;
    let caption: String = name + " " + GetLocalizedText(name) + " " + GetCaptionTagsFromArray(parts.parts);
    let i: Int32 = 0;
    while i < ArraySize(parts.parts) {
      textPart = parts.parts[i] as InteractionChoiceCaptionStringPart;
      if IsDefined(textPart) {
        caption += " " + textPart.content + " " + GetLocalizedText(textPart.content);
      };
      i += 1;
    };
    return caption;
  }

  public final static func IsSleepCaption(text: String) -> Bool {
    let raw: String = StrLower(text);
    let translated: String = StrLower(GetLocalizedText(text));
    return AdamDreamBedChoices.MatchesSleep(raw) || AdamDreamBedChoices.MatchesSleep(translated);
  }

  private final static func MatchesSleep(text: String) -> Bool {
    return StrContains(text, "잠을 잔다") || StrContains(text, "잠자") || StrContains(text, "잠들") || StrContains(text, "수면") || StrContains(text, "눕기")
      || StrContains(text, "잠을 잔") || StrContains(text, "sleep") || StrContains(text, "lie down") || StrContains(text, "go to bed");
  }

  public final static func CanOffer(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) || player.IsReplacer() || player.IsDead() || player.IsInCombat() {
      return false;
    };
    if IsDefined(player.adamArenaController) && player.adamArenaController.IsDreamProtected() {
      return false;
    };
    return !GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UI_System).GetBool(GetAllBlackboardDefs().UI_System.IsInMenu)
      && !GameInstance.GetWorkspotSystem(player.GetGame()).IsActorInWorkspot(player);
  }

  public final static func DeviceHasSleep(data: InteractionChoiceHubData) -> Bool {
    let i: Int32 = 0;
    if !data.active {
      return false;
    };
    while i < ArraySize(data.choices) {
      if AdamDreamBedChoices.IsSleepCaption(AdamDreamBedChoices.FullCaption(data.choices[i].localizedName, data.choices[i].captionParts))
        && !ChoiceTypeWrapper.IsType(data.choices[i].type, gameinteractionsChoiceType.Inactive)
        && !ChoiceTypeWrapper.IsType(data.choices[i].type, gameinteractionsChoiceType.CheckFailed) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  public final static func DialogHasSleep(hub: ListChoiceHubData) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(hub.choices) {
      if AdamDreamBedChoices.IsSleepCaption(AdamDreamBedChoices.FullCaption(hub.choices[i].localizedName, hub.choices[i].captionParts))
        && !ChoiceTypeWrapper.IsType(hub.choices[i].type, gameinteractionsChoiceType.Inactive)
        && !ChoiceTypeWrapper.IsType(hub.choices[i].type, gameinteractionsChoiceType.CheckFailed) {
        return true;
      };
      i += 1;
    };
    return false;
  }

  public final static func RestoreNativeScroll(player: ref<PlayerPuppet>) -> Void {
    let board: ref<IBlackboard> = GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UIInteractions);
    let device: InteractionChoiceHubData = FromVariant<InteractionChoiceHubData>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.InteractionChoiceHub));
    let dialogs: DialogChoiceHubs = FromVariant<DialogChoiceHubs>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs));
    let loot: LootData = FromVariant<LootData>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.LootData));
    board.SetBool(GetAllBlackboardDefs().UIInteractions.HasScrollableInteraction, (device.active && ArraySize(device.choices) > 1) || ArraySize(dialogs.choiceHubs) > 1 || (loot.isActive && ArraySize(loot.choices) > 1));
  }

  public final static func HasAnyChoice(player: ref<PlayerPuppet>) -> Bool {
    let board: ref<IBlackboard> = GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UIInteractions);
    let device: InteractionChoiceHubData = FromVariant<InteractionChoiceHubData>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.InteractionChoiceHub));
    let dialogs: DialogChoiceHubs = FromVariant<DialogChoiceHubs>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs));
    return (device.active && ArraySize(device.choices) > 0) || ArraySize(dialogs.choiceHubs) > 0;
  }

  public final static func DebugState(player: ref<PlayerPuppet>) -> String {
    let board: ref<IBlackboard> = GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UIInteractions);
    let device: InteractionChoiceHubData = FromVariant<InteractionChoiceHubData>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.InteractionChoiceHub));
    let dialogs: DialogChoiceHubs = FromVariant<DialogChoiceHubs>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs));
    let result: String = "침대 진단 H=" + IntToString(EnumInt(PlayerPuppet.GetCurrentHighLevelState(player)))
      + " W=" + ToString(GameInstance.GetWorkspotSystem(player.GetGame()).IsActorInWorkspot(player))
      + " D=" + IntToString(ArraySize(device.choices)) + " Q=" + IntToString(ArraySize(dialogs.choiceHubs))
      + " 감지=" + ToString(AdamDreamBedChoices.HasSleepChoice(player));
    if ArraySize(device.choices) > 0 {
      result += "\nD: " + AdamDreamBedChoices.FullCaption(device.choices[0].localizedName, device.choices[0].captionParts);
    };
    if ArraySize(dialogs.choiceHubs) > 0 && ArraySize(dialogs.choiceHubs[0].choices) > 0 {
      result += "\nQ: " + AdamDreamBedChoices.FullCaption(dialogs.choiceHubs[0].choices[0].localizedName, dialogs.choiceHubs[0].choices[0].captionParts);
    };
    return result;
  }

  public final static func HasSleepChoice(player: ref<PlayerPuppet>) -> Bool {
    let board: ref<IBlackboard>;
    let device: InteractionChoiceHubData;
    let dialogs: DialogChoiceHubs;
    let i: Int32 = 0;
    if !AdamDreamBedChoices.CanOffer(player) {
      return false;
    };
    board = GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UIInteractions);
    device = FromVariant<InteractionChoiceHubData>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.InteractionChoiceHub));
    if AdamDreamBedChoices.DeviceHasSleep(device) {
      return true;
    };
    dialogs = FromVariant<DialogChoiceHubs>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs));
    while i < ArraySize(dialogs.choiceHubs) {
      if AdamDreamBedChoices.DialogHasSleep(dialogs.choiceHubs[i]) {
        return true;
      };
      i += 1;
    };
    return false;
  }
}

public class AdamDreamHealthListener extends CustomValueStatPoolsListener {
  public let controller: wref<AdamArenaController>;

  public func OnStatPoolValueChanged(oldValue: Float, newValue: Float, percToPoints: Float) -> Void {
    if newValue <= 2.05 && IsDefined(this.controller) {
      this.controller.MarkDreamDefeat();
    };
  }
}

// Prevent lethal health loss before the native death pipeline, only in this dream.
@wrapMethod(StatPoolsManager)
public final static func DrainStatPool(hitEvent: ref<gameHitEvent>, statPoolType: gamedataStatPoolType, value: Float) -> Void {
  let player: ref<PlayerPuppet> = hitEvent.target as PlayerPuppet;
  if Equals(statPoolType, gamedataStatPoolType.Health) && IsDefined(player) && IsDefined(player.adamArenaController) && player.adamArenaController.IsDreamProtected() {
    hitEvent.attackData.SetMinimumHealthPercent(MaxF(hitEvent.attackData.GetMinimumHealthPercent(), 2.00));
  };
  wrappedMethod(hitEvent, statPoolType, value);
}

@wrapMethod(DeathDecisions)
protected final const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) && IsDefined(player.adamArenaController) && player.adamArenaController.IsDreamProtected() {
    if player.GetPuppetPS().GetIsDead() || scriptInterface.GetStatPoolsSystem().HasStatPoolValueReachedMin(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health) {
      player.adamArenaController.MarkDreamDefeat();
    };
    return false;
  };
  return wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(PlayerPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  if IsDefined(this.adamArenaController) && this.adamArenaController.IsDreamProtected() {
    this.GetPuppetPS().SetIsDead(false);
    this.adamArenaController.MarkDreamDefeat();
    GameInstance.GetStatPoolsSystem(this.GetGame()).RequestSettingStatPoolValue(Cast<StatsObjectID>(this.GetEntityID()), gamedataStatPoolType.Health, 100.00, this, true);
    return true;
  };
  return wrappedMethod(evt);
}

// Use an explicit effective limit in the actual encumbrance calculation. A
// blackboard-only number or a rejected/clamped stat modifier is insufficient.
@replaceMethod(PlayerPuppet)
public final func EvaluateEncumbrance(opt isLootBroken: Bool) -> Void {
  let carryCapacity: Float;
  let hasEncumbranceEffect: Bool;
  let isApplyingRestricted: Bool;
  let overweightEffectID: TweakDBID;
  let ses: ref<StatusEffectSystem>;
  if this.m_curInventoryWeight < 0.00 { this.m_curInventoryWeight = 0.00; };
  ses = GameInstance.GetStatusEffectSystem(this.GetGame());
  overweightEffectID = t"BaseStatusEffect.Encumbered";
  hasEncumbranceEffect = ses.HasStatusEffect(this.GetEntityID(), overweightEffectID);
  isApplyingRestricted = StatusEffectSystem.ObjectHasStatusEffectWithTag(this, n"NoEncumbrance");
  carryCapacity = AdamCapacityRules.EffectiveCarryCapacity(this);
  if this.m_curInventoryWeight > carryCapacity && !isApplyingRestricted && !isLootBroken && !hasEncumbranceEffect {
    this.SetWarningMessage(GetLocalizedText("UI-Notifications-Overburden"));
    ses.ApplyStatusEffect(this.GetEntityID(), overweightEffectID);
  } else {
    if (this.m_curInventoryWeight <= carryCapacity || isApplyingRestricted) && hasEncumbranceEffect {
      ses.RemoveStatusEffect(this.GetEntityID(), overweightEffectID);
    };
  };
  GameInstance.GetBlackboardSystem(this.GetGame()).Get(GetAllBlackboardDefs().UI_PlayerStats).SetFloat(GetAllBlackboardDefs().UI_PlayerStats.currentInventoryWeight, this.m_curInventoryWeight, true);
}

// Read the player owned by each menu; do not resolve a global game/player from the UI.

@wrapMethod(MenuHubGameController)
protected cb func OnPlayerMaxWeightUpdated(value: Int32) -> Bool {
  wrappedMethod(value);
  if IsDefined(this.m_player) && IsDefined(this.m_subMenuCtrl) && AdamCapacityRules.IsOverloaded(this.m_player) {
    this.m_subMenuCtrl.HandlePlayerMaxWeightUpdated(1, this.m_player.m_curInventoryWeight);
  };
}

@wrapMethod(MenuHubGameController)
public final func HandlePlayerWeightUpdated(opt dropQueueWeight: Float) -> Void {
  wrappedMethod(dropQueueWeight);
  if IsDefined(this.m_player) && IsDefined(this.m_subMenuCtrl) && AdamCapacityRules.IsOverloaded(this.m_player) {
    this.m_subMenuCtrl.HandlePlayerWeightUpdated(this.m_player.m_curInventoryWeight - dropQueueWeight, 1);
  };
}


@wrapMethod(RadialMenuHubGameController)
protected cb func OnPlayerMaxWeightUpdated(value: Int32) -> Bool {
  wrappedMethod(value);
  if IsDefined(this.m_player) && IsDefined(this.m_subMenuCtrl) && AdamCapacityRules.IsOverloaded(this.m_player) {
    this.m_subMenuCtrl.HandlePlayerMaxWeightUpdated(1, this.m_player.m_curInventoryWeight);
  };
}

@wrapMethod(RadialMenuHubGameController)
public final func HandlePlayerWeightUpdated(opt dropQueueWeight: Float) -> Void {
  wrappedMethod(dropQueueWeight);
  if IsDefined(this.m_player) && IsDefined(this.m_subMenuCtrl) && AdamCapacityRules.IsOverloaded(this.m_player) {
    this.m_subMenuCtrl.HandlePlayerWeightUpdated(this.m_player.m_curInventoryWeight - dropQueueWeight, 1);
  };
}

@wrapMethod(VendorHubMenuGameController)
protected cb func OnPlayerWeightUpdated(value: Float) -> Bool {
  if IsDefined(this.m_player) && AdamCapacityRules.IsOverloaded(this.m_player) {
    inkTextRef.SetText(this.m_playerWeightValue, IntToString(RoundF(this.m_player.m_curInventoryWeight)) + "/1");
    return true;
  };
  return wrappedMethod(value);
}

@wrapMethod(InventoryDataManagerV2)
private final func GetPlayerStatsFromMap(statsList: script_ref<array<StatViewData>>, const uiMap: script_ref<String>) -> Void {
  let entries: array<StatViewData>;
  let i: Int32;
  wrappedMethod(statsList, uiMap);
  if !AdamCapacityRules.IsOverloaded(this.m_Player) { return; };
  entries = Deref(statsList);
  i = 0;
  while i < ArraySize(entries) {
    if Equals(entries[i].type, gamedataStatType.CarryCapacity) {
      entries[i].value = 1;
      entries[i].valueF = 1.00;
    };
    i += 1;
  };
  statsList = entries;
}

// Use the existing dialog hub's font, layout, input glyph and selected-row
// styling. No separate canvas, font-size guess or duplicate sleep panel.
@addField(PlayerPuppet)
public let adamBedPickerDrawn: Bool;
@addField(PlayerPuppet)
public let adamBedPickerCreated: Bool;
@addField(PlayerPuppet)
public let adamBedHosts: Int32;
@addField(PlayerPuppet)
public let adamBedCreationStage: String;
@addField(PlayerPuppet)
public let adamBedPickers: array<ref<AdamBedPicker>>;
@addField(PlayerPuppet)
public let adamBedHookEvents: Int32;

public class AdamBedPicker extends IScriptable {
  private let host: wref<dialogWidgetGameController>;
  private let player: wref<PlayerPuppet>;
  private let running: Bool;
  private let visible: Bool;

  public final func Start(host: ref<dialogWidgetGameController>) -> Void {
    this.host = host;
    this.running = true;
  }

  public final func BindPlayer(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) || player.IsReplacer() { return; };
    if IsDefined(this.player) && this.player != player {
      ArrayRemove(this.player.adamBedPickers, this);
      this.player.adamBedHosts = ArraySize(this.player.adamBedPickers);
      this.player.adamBedPickerDrawn = false;
      this.visible = false;
    };
    this.player = player;
    if !ArrayContains(player.adamBedPickers, this) {
      ArrayPush(player.adamBedPickers, this);
      player.adamBedHosts = ArraySize(player.adamBedPickers);
    };
    this.Refresh();
  }

  public final func Stop() -> Void {
    this.running = false;
    if IsDefined(this.player) {
      this.player.adamBedPickerDrawn = false;
      AdamDreamBedChoices.RestoreNativeScroll(this.player);
      ArrayRemove(this.player.adamBedPickers, this);
      this.player.adamBedHosts = ArraySize(this.player.adamBedPickers);
    };
    this.visible = false;
  }

  public final func Refresh() -> Void {
    let source: DialogChoiceHubs;
    let board: ref<IBlackboard>;
    let shouldShow: Bool;
    if !this.running || !IsDefined(this.player) || !IsDefined(this.host) || !IsDefined(this.player.adamArenaController) { return; };
    board = GameInstance.GetBlackboardSystem(this.player.GetGame()).Get(GetAllBlackboardDefs().UIInteractions);
    source = FromVariant<DialogChoiceHubs>(board.GetVariant(GetAllBlackboardDefs().UIInteractions.DialogChoiceHubs));
    shouldShow = this.player.adamArenaController.BedMenuVisible() && AdamDreamBedChoices.SingleSleepHub(source) >= 0;
    if shouldShow {
      if !this.visible { this.player.adamArenaController.ChooseBedOption(0); };
      this.visible = true;
      this.host.AdamRenderBed(source, this.player.adamArenaController.BedSelection());
      this.player.adamBedPickerCreated = this.host.AdamBedRowsReady();
      this.player.adamBedPickerDrawn = this.player.adamBedPickerCreated;
      this.player.adamBedCreationStage = this.player.adamBedPickerCreated ? "기본 게임 선택지 2개 표시" : "기본 게임 선택지 생성 대기";
      board.SetBool(GetAllBlackboardDefs().UIInteractions.HasScrollableInteraction, true);
    } else {
      if this.visible {
        this.visible = false;
        this.player.adamBedPickerDrawn = false;
        this.host.AdamRestoreBed(source, this.player);
        AdamDreamBedChoices.RestoreNativeScroll(this.player);
      };
    };
  }

  public final func Input(evt: ref<inkPointerEvent>, pressed: Bool) -> Bool {
    let confirm: Bool = evt.IsAction(n"Choice1") || evt.IsAction(n"ChoiceApply") || evt.IsAction(n"Choice1_Release") || evt.IsAction(n"Choice1_Hold");
    if !this.visible || !IsDefined(this.player) || !this.player.adamBedPickerDrawn { return false; };
    if pressed && (evt.IsAction(n"ChoiceScrollUp") || evt.IsAction(n"UI_MoveUp")) {
      this.player.adamArenaController.ChooseBedOption(0);
      this.Refresh();
      evt.Consume();
      return true;
    };
    if pressed && (evt.IsAction(n"ChoiceScrollDown") || evt.IsAction(n"UI_MoveDown")) {
      this.player.adamArenaController.ChooseBedOption(1);
      this.Refresh();
      evt.Consume();
      return true;
    };
    if confirm && this.player.adamArenaController.ConfirmBedOption() {
      evt.Consume();
      return true;
    };
    return false;
  }

  public final func Axis(evt: ref<inkPointerEvent>) -> Bool {
    if !this.visible || !IsDefined(this.player) || !this.player.adamBedPickerDrawn { return false; };
    if evt.IsAction(n"mouse_wheel") || evt.IsAction(n"UI_ScrollVertically") {
      if evt.GetAxisData() < 0.00 { this.player.adamArenaController.ChooseBedOption(1); }
      else { this.player.adamArenaController.ChooseBedOption(0); };
      this.Refresh();
      evt.Consume();
      return true;
    };
    return false;
  }
}

@addMethod(DialogHubLogicController)
public final func AdamBedRowsReady() -> Bool {
  return this.m_pendingRequests <= 0 && ArraySize(this.m_itemControllers) == 2;
}

@addField(dialogWidgetGameController)
private let adamBedPicker: ref<AdamBedPicker>;
@addField(dialogWidgetGameController)
private let adamBedPainting: Bool;

@addMethod(dialogWidgetGameController)
public final func AdamRenderBed(source: DialogChoiceHubs, selected: Int32) -> Void {
  let index: Int32 = AdamDreamBedChoices.SingleSleepHub(source);
  if index < 0 { return; };
  this.adamBedPainting = true;
  this.m_data = AdamDreamBedChoices.NativeBedView(source, index);
  this.m_activeHubID = source.choiceHubs[index].id;
  this.m_selectedIndex = selected;
  this.m_AreDialogsOpen = true;
  this.OnInteractionsChanged();
  this.adamBedPainting = false;
}

@addMethod(dialogWidgetGameController)
public final func AdamRestoreBed(source: DialogChoiceHubs, player: ref<PlayerPuppet>) -> Void {
  let board: ref<IBlackboard> = GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UIInteractions);
  this.adamBedPainting = true;
  this.m_data = source;
  this.m_activeHubID = board.GetInt(GetAllBlackboardDefs().UIInteractions.ActiveChoiceHubID);
  this.m_selectedIndex = board.GetInt(GetAllBlackboardDefs().UIInteractions.SelectedIndex);
  this.m_AreDialogsOpen = ArraySize(source.choiceHubs) > 0;
  this.OnInteractionsChanged();
  this.adamBedPainting = false;
}

@addMethod(dialogWidgetGameController)
public final func AdamBedRowsReady() -> Bool {
  let i: Int32 = 0;
  while i < ArraySize(this.m_hubControllers) {
    if IsDefined(this.m_hubControllers[i]) && this.m_hubControllers[i].GetId() == this.m_activeHubID {
      return this.m_hubControllers[i].AdamBedRowsReady();
    };
    i += 1;
  };
  return false;
}

@addMethod(dialogWidgetGameController)
private final func AdamEnsureBedPicker() -> Void {
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  if !IsDefined(this.adamBedPicker) {
    this.adamBedPicker = new AdamBedPicker();
    this.adamBedPicker.Start(this);
  };
  if IsDefined(player) {
    player.adamBedHookEvents += 1;
    this.adamBedPicker.BindPlayer(player);
  };
}

@wrapMethod(dialogWidgetGameController)
protected cb func OnInitialize() -> Bool {
  wrappedMethod();
  this.AdamEnsureBedPicker();
  this.RegisterToGlobalInputCallback(n"OnPreOnPress", this, n"OnAdamBedPress");
  this.RegisterToGlobalInputCallback(n"OnPreOnRelease", this, n"OnAdamBedRelease");
  this.RegisterToGlobalInputCallback(n"OnPostOnAxis", this, n"OnAdamBedAxis");
}

@wrapMethod(dialogWidgetGameController)
protected cb func OnUninitialize() -> Bool {
  this.UnregisterFromGlobalInputCallback(n"OnPreOnPress", this, n"OnAdamBedPress");
  this.UnregisterFromGlobalInputCallback(n"OnPreOnRelease", this, n"OnAdamBedRelease");
  this.UnregisterFromGlobalInputCallback(n"OnPostOnAxis", this, n"OnAdamBedAxis");
  if IsDefined(this.adamBedPicker) { this.adamBedPicker.Stop(); };
  this.adamBedPicker = null;
  wrappedMethod();
}

@addMethod(dialogWidgetGameController)
protected cb func OnAdamBedPress(evt: ref<inkPointerEvent>) -> Bool {
  if IsDefined(this.adamBedPicker) { return this.adamBedPicker.Input(evt, true); };
  return false;
}
@addMethod(dialogWidgetGameController)
protected cb func OnAdamBedRelease(evt: ref<inkPointerEvent>) -> Bool {
  if IsDefined(this.adamBedPicker) { return this.adamBedPicker.Input(evt, false); };
  return false;
}
@addMethod(dialogWidgetGameController)
protected cb func OnAdamBedAxis(evt: ref<inkPointerEvent>) -> Bool {
  if IsDefined(this.adamBedPicker) { return this.adamBedPicker.Axis(evt); };
  return false;
}

@wrapMethod(dialogWidgetGameController)
protected func OnInteractionsChanged() -> Void {
  wrappedMethod();
  if !this.adamBedPainting { this.AdamEnsureBedPicker(); };
}

@addMethod(dialogWidgetGameController)
protected cb func OnPlayerAttach(playerGameObject: ref<GameObject>) -> Bool {
  let player: ref<PlayerPuppet> = playerGameObject as PlayerPuppet;
  this.AdamEnsureBedPicker();
  if IsDefined(player) {
    player.adamBedHookEvents += 1;
    this.adamBedPicker.BindPlayer(player);
  };
  return true;
}
@addMethod(dialogWidgetGameController)
protected cb func OnPlayerDetach(playerGameObject: ref<GameObject>) -> Bool {
  if IsDefined(this.adamBedPicker) { this.adamBedPicker.Stop(); };
  this.adamBedPicker = null;
  return true;
}


// Native macOS: return the exact ingredient from a Chimera mod's recipe.
// Preview is pure. Only an actual successful inventory removal grants a core.
public abstract class AdamChimeraRules {
  public final static func IsChimera(itemID: ItemID) -> Bool {
    let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemID));
    return IsDefined(record) && record.TagsContains(n"ChimeraMod");
  }

  public final static func CoreRecord(itemID: ItemID) -> ref<Item_Record> {
    let recipe: array<wref<RecipeElement_Record>>;
    let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemID));
    let none: ref<Item_Record>;
    if !IsDefined(record) || !record.TagsContains(n"ChimeraMod") || !IsDefined(record.CraftingData()) {
      return none;
    };
    record.CraftingData().CraftingRecipe(recipe);
    // Fail closed if another mod changed the one-core recipe structure.
    if ArraySize(recipe) != 1 || !IsDefined(recipe[0]) || recipe[0].Amount() != 1 {
      return none;
    };
    return recipe[0].Ingredient();
  }

  public final static func CanRecycle(itemData: wref<gameItemData>) -> Bool {
    return IsDefined(itemData) && !itemData.HasTag(n"Quest") && !itemData.HasTag(n"UnequipBlocked") && IsDefined(AdamChimeraRules.CoreRecord(itemData.GetID()));
  }

  public final static func RemovedCount(before: Int32, after: Int32, requested: Int32) -> Int32 {
    if before <= 0 || after < 0 || requested <= 0 || after >= before {
      return 0;
    };
    return Min(requested, before - after);
  }

  public final static func Queue(executor: wref<GameObject>, itemID: ItemID, quantity: Int32) -> Void {
    let request: ref<DisassembleItemRequest>;
    let player: ref<PlayerPuppet> = executor as PlayerPuppet;
    let crafting: ref<CraftingSystem>;
    if !IsDefined(player) || player.IsReplacer() || quantity <= 0 {
      return;
    };
    crafting = CraftingSystem.GetInstance(executor.GetGame());
    if !crafting.CanItemBeDisassembled(executor, itemID) {
      return;
    };
    request = new DisassembleItemRequest();
    request.target = executor;
    request.itemID = itemID;
    request.amount = quantity;
    crafting.QueueRequest(request);
  }
}

@wrapMethod(CraftingSystem)
public final const func CanItemBeDisassembled(itemData: wref<gameItemData>) -> Bool {
  if IsDefined(itemData) && AdamChimeraRules.IsChimera(itemData.GetID()) {
    return AdamChimeraRules.CanRecycle(itemData);
  };
  return wrappedMethod(itemData);
}

// Some iconic mods have no Disassemble object action. Use the same native
// request queue after the inventory UI's hold/quantity/confirmation handling.
@wrapMethod(ItemActionsHelper)
public final static func DisassembleItem(executor: wref<GameObject>, itemID: ItemID) -> Void {
  if AdamChimeraRules.IsChimera(itemID) {
    AdamChimeraRules.Queue(executor, itemID, 1);
    return;
  };
  wrappedMethod(executor, itemID);
}

@wrapMethod(ItemActionsHelper)
public final static func DisassembleItem(executor: wref<GameObject>, itemID: ItemID, quantity: Int32) -> Void {
  if AdamChimeraRules.IsChimera(itemID) {
    AdamChimeraRules.Queue(executor, itemID, quantity);
    return;
  };
  wrappedMethod(executor, itemID, quantity);
}

@wrapMethod(CraftingSystem)
public final const func GetDisassemblyResultItems(target: wref<GameObject>, itemID: ItemID, amount: Int32, restoredAttachments: script_ref<[ItemAttachments]>, opt calledFromUI: Bool) -> [IngredientData] {
  let result: array<IngredientData>;
  let core: ref<Item_Record>;
  if AdamChimeraRules.IsChimera(itemID) {
    core = AdamChimeraRules.CoreRecord(itemID);
    if IsDefined(core) && amount > 0 {
      ArrayPush(result, this.CreateIngredientData(core, amount));
    };
    return result;
  };
  return wrappedMethod(target, itemID, amount, restoredAttachments, calledFromUI);
}

@wrapMethod(CraftingSystem)
private final const func DisassembleItem(target: wref<GameObject>, itemID: ItemID, amount: Int32) -> Void {
  let player: ref<PlayerPuppet>;
  let transaction: ref<TransactionSystem>;
  let itemData: wref<gameItemData>;
  let core: ref<Item_Record>;
  let before: Int32;
  let quantity: Int32;
  let removed: Int32;
  let result: array<IngredientData>;
  if !AdamChimeraRules.IsChimera(itemID) {
    wrappedMethod(target, itemID, amount);
    return;
  };
  player = target as PlayerPuppet;
  if !IsDefined(player) || player.IsReplacer() || amount <= 0 {
    return;
  };
  transaction = GameInstance.GetTransactionSystem(target.GetGame());
  itemData = transaction.GetItemData(target, itemID);
  if !AdamChimeraRules.CanRecycle(itemData) || RPGManager.IsItemEquipped(target, itemID) || transaction.HasItemInAnySlot(target, itemID) {
    return;
  };
  core = AdamChimeraRules.CoreRecord(itemID);
  before = transaction.GetItemQuantity(target, itemID);
  quantity = Min(before, amount);
  if quantity <= 0 {
    return;
  };
  if !transaction.RemoveItem(target, itemID, quantity) {
    return;
  };
  removed = AdamChimeraRules.RemovedCount(before, transaction.GetItemQuantity(target, itemID), quantity);
  if removed <= 0 {
    return;
  };
  if !transaction.GiveItem(target, ItemID.FromTDBID(core.GetID()), removed) {
    // Keep the user's crafted mod if the core cannot be added.
    transaction.GiveItem(target, itemID, removed);
    return;
  };
  this.m_playerCraftBook.AdamRestoreChimeraRecipes(core.GetID());
  GameInstance.GetTelemetrySystem(this.GetGameInstance()).LogItemDisassembled(target, itemID);
  ArrayPush(result, this.CreateIngredientData(core, removed));
  this.UpdateBlackboard(CraftingCommands.DisassemblingFinished, itemID, result);
}

// These recipes can be hidden once one of the four mods is crafted.
// Restore only recipes already learned and using the same returned core.
@addMethod(CraftBook)
public final func AdamRestoreChimeraRecipes(coreID: TweakDBID) -> Void {
  let record: ref<Item_Record>;
  let core: ref<Item_Record>;
  let i: Int32 = 0;
  while i < ArraySize(this.m_knownRecipes) {
    record = TweakDBInterface.GetItemRecord(this.m_knownRecipes[i].targetItem);
    if IsDefined(record) && record.TagsContains(n"ChimeraMod") {
      core = AdamChimeraRules.CoreRecord(ItemID.FromTDBID(record.GetID()));
      if IsDefined(core) && core.GetID() == coreID {
        this.m_knownRecipes[i].isHidden = false;
      };
    };
    i += 1;
  };
}
