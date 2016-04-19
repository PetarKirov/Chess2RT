module util.random;

import std.c.stdlib : rand, srand, RAND_MAX;
import std.c.time : time;
import std.traits : CommonType;

static this()
{
    srand(cast(uint)time(null));
}

template uniform(T1, T2)
{
    alias Result = CommonType!(T1, T2);

    static assert(!is(Result == void));

    // TODO: Switch to MT19937 or better.
    Result uniform (T1 a, T2 b) @safe nothrow @nogc
    {
        double r = rand();

        auto delta = b - a;

        auto result = a + (r / RAND_MAX) * delta;

        return cast(Result)result;
    }
}

@safe nothrow @nogc unittest
{
    foreach (_; 0 .. 10)
    {
        auto res1 = uniform(0.0, 1.0);
        assert(res1 >= 0.0 && res1 < 1.0);

        auto res2 = uniform(-42, 42);
        assert(res2 >= -42 && res2 < 42);

        auto res3 = uniform(10_000, 2_000_000);
        assert(res3 >= 10_000 && res3 < 2_000_000);
    }
}

//
//
//import std.traits, std.range;
//
//uint unpredictableSeed() @property @nogc
//{
//  return 0;
//}
//
//ref Random rndGen() @property @nogc
//{
//  static Random result = null;
//
//  if (result is null)
//  {
//      import std.c.stdlib;
//
//      result =  cast(Random)malloc(__traits(classInstanceSize, Random));
//
//      result.seed(unpredictableSeed);
//  }
//
//  return result;
//}
//
//
//alias Random = Mt19937;
//alias Mt19937 = MersenneTwisterEngine!(uint,
//                         32, 624, 397, 31,
//                         0x9908b0dfU, 11, 0xffffffffU, 7,
//                         0x9d2c5680U, 15,
//                         0xefc60000U, 18, 1812433253U);
//
//final class MersenneTwisterEngine(UIntType,
//                                  size_t w, size_t n, size_t m, size_t r,
//                                  UIntType a, size_t u, UIntType d, size_t s,
//                                  UIntType b, size_t t,
//                                  UIntType c, size_t l, UIntType f)
//  if (isUnsigned!UIntType)
//{
//private:
//  UIntType[n] mt;
//  UIntType _y;
//  size_t mti = size_t.max;   // means mt is not initialized
//
//public:
//  /// Mark this as a uniform RNG
//  enum bool isUniformRandom = true;
//
//  /// Parameters for the generator
//  enum size_t wordSize = w;
//  enum size_t stateSize = n;
//  enum size_t shiftSize = m;
//  enum size_t maskBits = r;
//  enum UIntType xorMask = a;
//  enum size_t temperingU = u;
//  enum UIntType temperingD = d;
//  enum size_t temperingS = s;
//  enum UIntType temperingB = b;
//  enum size_t temperingT = t;
//  enum UIntType temperingC = c;
//  enum size_t temperingL = l;
//  enum UIntType initializationMultiplier = f;
//
//  /// Smallest generated value (0)
//  enum UIntType min = 0;
//
//  /// Largest generated value
//  enum UIntType max = UIntType.max >> (UIntType.sizeof * 8u - w);
//
//  /// Default seed value
//  enum UIntType defaultSeed = 5489U;
//
//  /// Constructs a $(D MersenneTwisterEngine) using the default seed.
//  this() @safe
//  {
//      seed(this.defaultSeed);
//  }
//
//  /// Constructs a $(D MersenneTwisterEngine) seeded with $(D_PARAM value).
//  this(in UIntType value) @safe
//  {
//      seed(value);
//  }
//
//  void seed()(in UIntType value) @safe nothrow pure
//  {
//      enum UIntType mask = this.max;
//      mt[0] = value & mask;
//      for (mti = 1; mti < n; ++mti)
//      {
//          mt[mti] = (f * (mt[mti - 1] ^ (mt[mti - 1] >> (w - 2))) + mti) & mask;
//      }
//      popFront();
//  }
//
//  void seed(Range)(Range range)
//      if (isInputRange!Range && is(Unqual!(ElementType!Range) : UIntType))
//  {
//      size_t j;
//      for (j = 0; j < n && !range.empty; ++j, range.popFront())
//      {
//          mt[j] = range.front;
//      }
//
//      mti = n;
//      if (range.empty && j < n)
//      {
//          import std.exception, std.string : format;
//          throw new Exception(format("%s.seed: Input range only provided %s elements, " ~
//                                     "need at least %s.", typeof(this).stringof, j, n));
//      }
//
//      popFront();
//  }
//
//  // ----- Range primitives -------------------------------------------------
//
//  /// Always $(D false) (random number generators are infinite ranges).
//  enum bool empty = false;
//
//  /// Returns the current pseudo-random value.
//  UIntType front() @property @safe const nothrow pure
//      in
//  {
//      assert(mti < size_t.max);
//  }
//  body
//  {
//      return _y;
//  }
//
//  /// Advances the pseudo-random sequence.
//  void popFront() @safe nothrow pure
//      in
//  {
//      assert(mti < size_t.max);
//  }
//  body
//  {
//      enum UIntType upperMask = (~(cast(UIntType) 0)) << r;
//      enum UIntType lowerMask = ~upperMask;
//
//      enum size_t unrollFactor = 6;
//      enum size_t unrollExtra1 = (n - m) % unrollFactor;
//      enum size_t unrollExtra2 = (m - 1) % unrollFactor;
//
//      UIntType y = void;
//
//      if (mti >= n)
//      {
//          foreach (j; 0 .. n - m - unrollExtra1)
//          {
//              y = (mt[j] & upperMask) | (mt[j + 1] & lowerMask);
//              mt[j] = mt[j + m] ^ (y >> 1) ^ ((mt[j + 1] & 1) * a);
//          }
//
//          foreach (j; n - m - unrollExtra1 .. n - m)
//          {
//              y = (mt[j] & upperMask) | (mt[j + 1] & lowerMask);
//              mt[j] = mt[j + m] ^ (y >> 1) ^ ((mt[j + 1] & 1) * a);
//          }
//
//          foreach (j; n - m .. n - 1 - unrollExtra2)
//          {
//              y = (mt[j] & upperMask) | (mt[j + 1] & lowerMask);
//              mt[j] = mt[j - (n - m)] ^ (y >> 1) ^ ((mt[j + 1] & 1) * a);
//          }
//
//          foreach (j; n - 1 - unrollExtra2 .. n - 1)
//          {
//              y = (mt[j] & upperMask) | (mt[j + 1] & lowerMask);
//              mt[j] = mt[j - (n - m)] ^ (y >> 1) ^ ((mt[j + 1] & 1) * a);
//          }
//
//          y = (mt[n - 1] & upperMask) | (mt[0] & lowerMask);
//          mt[n - 1] = mt[m - 1] ^ (y >> 1) ^ ((mt[0] & 1) * a);
//
//          mti = 0;
//      }
//
//      y = mt[mti];
//      mti++;
//      y ^= ((y >> u) & d);
//      y ^= ((y << s) & b);
//      y ^= ((y << t) & c);
//      y ^= (y >> l);
//
//      _y = y;
//  }
//
//  typeof(this) save() @property @safe
//  {
//      auto ret = new typeof(this);
//      ret.mt[] = this.mt[];
//      ret._y = this._y;
//      ret.mti = this.mti;
//      return ret;
//  }
//
//  override bool opEquals(Object rhs) @safe const nothrow pure
//  {
//      auto that = cast(typeof(this)) rhs;
//
//      if (that is null)
//      {
//          return false;
//      }
//      else if (this.mt != that.mt || this._y != that._y || this.mti != that.mti)
//      {
//          return false;
//      }
//      else
//      {
//          return true;
//      }
//  }
//}
//
//pragma(msg, isUniformRNG!(typeof(rndGen)));
//
//
//
//
//
//auto uniform(string boundaries = "[)", T1, T2, UniformRNG)
//  (T1 a, T2 b, UniformRNG rng) @nogc
//      if (isFloatingPoint!(CommonType!(T1, T2)) && isUniformRNG!UniformRNG)
//          out (result)
//      {
//          // We assume "[)" as the common case
//          static if (boundaries[0] == '(')
//          {
//              assert(a < result);
//          }
//          else
//          {
//              assert(a <= result);
//          }
//
//          static if (boundaries[1] == ']')
//          {
//              assert(result <= b);
//          }
//          else
//          {
//              assert(result < b);
//          }
//}
//body
//{
//  import std.exception, std.math, std.string : format;
//  alias NumberType = Unqual!(CommonType!(T1, T2));
//  static if (boundaries[0] == '(')
//  {
//      NumberType _a = nextafter(cast(NumberType) a, NumberType.infinity);
//  }
//  else
//  {
//      NumberType _a = a;
//  }
//  static if (boundaries[1] == ')')
//  {
//      NumberType _b = nextafter(cast(NumberType) b, -NumberType.infinity);
//  }
//  else
//  {
//      NumberType _b = b;
//  }
//
//  assert(_a <= _b);
////    enforce(_a <= _b ,
////            format("hap.random.distribution.uniform(): invalid bounding interval %s%s, %s%s",
////           boundaries[0], a, b, boundaries[1]));
//
//  NumberType result = _a + (_b - _a) * cast(NumberType) (rng.front - rng.min)
//          / (rng.max - rng.min);
//  rng.popFront();
//  return result;
//}
//
//template isUniformRNG(Range, ElementType)
//{
//  enum bool isUniformRNG = isInputRange!Range &&
//      is(typeof(Range.front) == ElementType) &&
//          is(typeof(Range.min) == ElementType) &&
//          is(typeof(Range.max) == ElementType) &&
//          isIntegral!ElementType &&
//          isUnsigned!ElementType &&
//          is(typeof(
//              {
//              static assert(Range.isUniformRandom); //tag
//          }));
//}
//
///// ditto
//template isUniformRNG(Range)
//{
//  enum bool isUniformRNG =
//      is(typeof(
//          {
//          static assert(isUniformRNG!(Range, typeof(Range.front)));
//      }));
//}
