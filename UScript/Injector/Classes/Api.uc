class Api extends Object dependsOn(
    Instance
);

static final function bool InjectDLL(const string DllStem) {
    local Instance Inst;
    local bool DidInit;

    Inst = new class'Instance';
    DidInit = Inst.Init();
    if(DidInit == False) {
        return DidInit;
    }

    return Inst.InjectDllWithStem(DllStem);
}
