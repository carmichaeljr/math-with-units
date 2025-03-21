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

pub fn Scale(u: Unit, exp: i64) Unit {
    var rv = u;
    rv.exp = exp;
    return rv;
}

// Increasing exponent powers
pub fn Deka(u: Unit) Unit {
    return Scale(u, 1);
}
pub fn Hecto(u: Unit) Unit {
    return Scale(u, 2);
}
pub fn Kilo(u: Unit) Unit {
    return Scale(u, 3);
}
pub fn Mega(u: Unit) Unit {
    return Scale(u, 6);
}
pub fn Giga(u: Unit) Unit {
    return Scale(u, 9);
}
pub fn Tera(u: Unit) Unit {
    return Scale(u, 12);
}
pub fn Peta(u: Unit) Unit {
    return Scale(u, 15);
}
pub fn Exa(u: Unit) Unit {
    return Scale(u, 18);
}
pub fn Zetta(u: Unit) Unit {
    return Scale(u, 21);
}
pub fn Yotta(u: Unit) Unit {
    return Scale(u, 24);
}
pub fn Ronna(u: Unit) Unit {
    return Scale(u, 27);
}
pub fn Quetta(u: Unit) Unit {
    return Scale(u, 30);
}

// Decreasing exponent powers
pub fn Deci(u: Unit) Unit {
    return Scale(u, -1);
}
pub fn Centi(u: Unit) Unit {
    return Scale(u, -2);
}
pub fn Milli(u: Unit) Unit {
    return Scale(u, -3);
}
pub fn Micro(u: Unit) Unit {
    return Scale(u, -6);
}
pub fn Nano(u: Unit) Unit {
    return Scale(u, -9);
}
pub fn Pico(u: Unit) Unit {
    return Scale(u, -12);
}
pub fn Femto(u: Unit) Unit {
    return Scale(u, -15);
}
pub fn Atto(u: Unit) Unit {
    return Scale(u, -18);
}
pub fn Zepto(u: Unit) Unit {
    return Scale(u, -21);
}
pub fn Yocto(u: Unit) Unit {
    return Scale(u, -24);
}
pub fn Ronto(u: Unit) Unit {
    return Scale(u, -27);
}
pub fn Quecto(u: Unit) Unit {
    return Scale(u, -30);
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
pub const kilogram = Unit{ .name = "kg", .base = 10, .exp = 3 };

// Comp sci base units
const byte2 = Unit{ .name = "byte2", .base = 2, .exp = 1 };
const byte10 = Unit{ .name = "byte10", .base = 10, .exp = 1 };
