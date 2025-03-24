const fmt = @import("std").fmt;

// The base value that describes a unit.
pub const Unit = struct {
    name: []const u8,
    base: i64 = 0,
    exp: i64 = 0,

    const strFmt = "{s}*{}^{}";
    pub fn comptimePrint(self: Unit) *const [fmt.count(strFmt, self):0]u8 {
        return fmt.comptimePrint(strFmt, self);
    }
};

pub fn scale(u: Unit, exp: i64) Unit {
    var rv = u;
    rv.exp = exp;
    return rv;
}

// Increasing exponent powers
pub fn deka(u: Unit) Unit {
    return scale(u, 1);
}
pub fn hecto(u: Unit) Unit {
    return scale(u, 2);
}
pub fn kilo(u: Unit) Unit {
    return scale(u, 3);
}
pub fn mega(u: Unit) Unit {
    return scale(u, 6);
}
pub fn giga(u: Unit) Unit {
    return scale(u, 9);
}
pub fn tera(u: Unit) Unit {
    return scale(u, 12);
}
pub fn peta(u: Unit) Unit {
    return scale(u, 15);
}
pub fn exa(u: Unit) Unit {
    return scale(u, 18);
}
pub fn zetta(u: Unit) Unit {
    return scale(u, 21);
}
pub fn yotta(u: Unit) Unit {
    return scale(u, 24);
}
pub fn ronna(u: Unit) Unit {
    return scale(u, 27);
}
pub fn quetta(u: Unit) Unit {
    return scale(u, 30);
}

// Decreasing exponent powers
pub fn deci(u: Unit) Unit {
    return scale(u, -1);
}
pub fn centi(u: Unit) Unit {
    return scale(u, -2);
}
pub fn milli(u: Unit) Unit {
    return scale(u, -3);
}
pub fn micro(u: Unit) Unit {
    return scale(u, -6);
}
pub fn nano(u: Unit) Unit {
    return scale(u, -9);
}
pub fn pico(u: Unit) Unit {
    return scale(u, -12);
}
pub fn femto(u: Unit) Unit {
    return scale(u, -15);
}
pub fn atto(u: Unit) Unit {
    return scale(u, -18);
}
pub fn zepto(u: Unit) Unit {
    return scale(u, -21);
}
pub fn yocto(u: Unit) Unit {
    return scale(u, -24);
}
pub fn ronto(u: Unit) Unit {
    return scale(u, -27);
}
pub fn quecto(u: Unit) Unit {
    return scale(u, -30);
}

// Scientific base units
pub const meter = Unit{ .name = "m", .base = 10, .exp = 1 };
pub const gram = Unit{ .name = "g", .base = 10, .exp = 1 };
pub const second = Unit{ .name = "s", .base = 10, .exp = 1 };
pub const ampere = Unit{ .name = "A", .base = 10, .exp = 1 };
pub const kelvin = Unit{ .name = "K", .base = 10, .exp = 1 };
pub const mole = Unit{ .name = "mol", .base = 10, .exp = 1 };
pub const candela = Unit{ .name = "cd", .base = 10, .exp = 1 };
// Defined for convienence because it is a SI standard unit
pub const kilogram = Unit{ .name = "g", .base = 10, .exp = 3 };

// Comp sci base units
const byte2 = Unit{ .name = "byte2", .base = 2, .exp = 1 };
const byte10 = Unit{ .name = "byte10", .base = 10, .exp = 1 };
