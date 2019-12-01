module util.atomic;

struct Atomic(T)
{
    import core.atomic : atomicLoad, atomicStore, core_cas = cas;

    private shared T _val;

    shared(T)* ptr() shared { return &_val; }

    bool cas(T oldVal, T newVal) shared
    {
        return core_cas(&this._val, oldVal, newVal);
    }

    @property bool get() shared
    {
        return atomicLoad(this._val);
    }

    void opAssign(bool newVal) shared
    {
        this._val.atomicStore(newVal);
    }

    alias get this;
}
