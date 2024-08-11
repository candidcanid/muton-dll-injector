class DevHookXComOnlineEventMgr extends XComOnlineEventMgr dependsOn(
    DevHookXComEngine
);

var bool HasInjected;

event Tick(float DeltaTime) {
    local bool Result;

    if(HasInjected == true) return;
    HasInjected = true;

    Result = class'Injector.Api'.static.InjectDLL(
        DevHookXComEngine(class'Engine'.static.GetEngine()).DllName
    );
    `log("Injector.InjectDLL(...) =: " $ Result);
}

