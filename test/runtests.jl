# This file includes code that was formerly a part of Julia. License is MIT: http://julialang.org/license

using Compat
using Compat.Test
using Compat: view, String
using LegacyStrings
using LegacyStrings: ASCIIString, UTF8String # override Compat's version
import LegacyStrings:
    checkstring,
    UnicodeError,
    UTF_ERR_SHORT

# types
nullstring16 = UInt16[]
badstring16  = UInt16[0x0065]
@test_throws UnicodeError UTF16String(nullstring16)
@test_throws UnicodeError UTF16String(badstring16)

nullstring32 = UInt32[]
badstring32  = UInt32['a']
@test_throws UnicodeError UTF32String(nullstring32)
@test_throws UnicodeError UTF32String(badstring32)

# Unicode errors
let io = IOBuffer()
    show(io, UnicodeError(UTF_ERR_SHORT, 1, 10))
    check = "UnicodeError: invalid UTF-8 sequence starting at index 1 (0xa missing one or more continuation bytes)"
    @test String(take!(io)) == check
end

## Test invalid sequences

# Continuation byte not after lead
for byt in 0x80:0xbf
    @test_throws UnicodeError checkstring(UInt8[byt])
end

# Test lead bytes
for byt in 0xc0:0xff
    # Single lead byte at end of string
    @test_throws UnicodeError checkstring(UInt8[byt])
    # Lead followed by non-continuation character < 0x80
    @test_throws UnicodeError checkstring(UInt8[byt,0])
    # Lead followed by non-continuation character > 0xbf
    @test_throws UnicodeError checkstring(UInt8[byt,0xc0])
end

# Test overlong 2-byte
for byt in 0x81:0xbf
    @test_throws UnicodeError checkstring(UInt8[0xc0,byt])
end
for byt in 0x80:0xbf
    @test_throws UnicodeError checkstring(UInt8[0xc1,byt])
end

# Test overlong 3-byte
for byt in 0x80:0x9f
    @test_throws UnicodeError checkstring(UInt8[0xe0,byt,0x80])
end

# Test overlong 4-byte
for byt in 0x80:0x8f
    @test_throws UnicodeError checkstring(UInt8[0xef,byt,0x80,0x80])
end

# Test 4-byte > 0x10ffff
for byt in 0x90:0xbf
    @test_throws UnicodeError checkstring(UInt8[0xf4,byt,0x80,0x80])
end
for byt in 0xf5:0xf7
    @test_throws UnicodeError checkstring(UInt8[byt,0x80,0x80,0x80])
end

# Test 5-byte
for byt in 0xf8:0xfb
    @test_throws UnicodeError checkstring(UInt8[byt,0x80,0x80,0x80,0x80])
end

# Test 6-byte
for byt in 0xfc:0xfd
    @test_throws UnicodeError checkstring(UInt8[byt,0x80,0x80,0x80,0x80,0x80])
end

# Test 7-byte
@test_throws UnicodeError checkstring(UInt8[0xfe,0x80,0x80,0x80,0x80,0x80,0x80])

# Three and above byte sequences
for byt in 0xe0:0xef
    # Lead followed by only 1 continuation byte
    @test_throws UnicodeError checkstring(UInt8[byt,0x80])
    # Lead ended by non-continuation character < 0x80
    @test_throws UnicodeError checkstring(UInt8[byt,0x80,0])
    # Lead ended by non-continuation character > 0xbf
    @test_throws UnicodeError checkstring(UInt8[byt,0x80,0xc0])
end

# 3-byte encoded surrogate character(s)
# Single surrogate
@test_throws UnicodeError checkstring(UInt8[0xed,0xa0,0x80])
# Not followed by surrogate
@test_throws UnicodeError checkstring(UInt8[0xed,0xa0,0x80,0xed,0x80,0x80])
# Trailing surrogate first
@test_throws UnicodeError checkstring(UInt8[0xed,0xb0,0x80,0xed,0xb0,0x80])
# Followed by lead surrogate
@test_throws UnicodeError checkstring(UInt8[0xed,0xa0,0x80,0xed,0xa0,0x80])

# Four byte sequences
for byt in 0xf0:0xf4
    # Lead followed by only 2 continuation bytes
    @test_throws UnicodeError checkstring(UInt8[byt,0x80,0x80])
    # Lead followed by non-continuation character < 0x80
    @test_throws UnicodeError checkstring(UInt8[byt,0x80,0x80,0])
    # Lead followed by non-continuation character > 0xbf
    @test_throws UnicodeError checkstring(UInt8[byt,0x80,0x80,0xc0])
end

# Long encoding of 0x01
@test_throws UnicodeError utf8(b"\xf0\x80\x80\x80")
# Test ends of long encoded surrogates
@test_throws UnicodeError utf8(b"\xf0\x8d\xa0\x80")
@test_throws UnicodeError utf8(b"\xf0\x8d\xbf\xbf")
@test_throws UnicodeError checkstring(b"\xf0\x80\x80\x80")
@test checkstring(b"\xc0\x81"; accept_long_char=true) == (1,0x1,0,0,0)
@test checkstring(b"\xf0\x80\x80\x80"; accept_long_char=true) == (1,0x1,0,0,0)

# Surrogates
@test_throws UnicodeError checkstring(UInt16[0xd800])
@test_throws UnicodeError checkstring(UInt16[0xdc00])
@test_throws UnicodeError checkstring(UInt16[0xdc00,0xd800])

# Surrogates in UTF-32
@test_throws UnicodeError checkstring(UInt32[0xd800])
@test_throws UnicodeError checkstring(UInt32[0xdc00])
@test_throws UnicodeError checkstring(UInt32[0xdc00,0xd800])

# Characters > 0x10ffff
@test_throws UnicodeError checkstring(UInt32[0x110000])

# Test starting and different position
@test checkstring(UInt32[0x110000, 0x1f596], 2) == (1,0x10,1,0,0)

# Test valid sequences
for (seq, res) in (
    (UInt8[0x0],                (1,0,0,0,0)),   # Nul byte, beginning of ASCII range
    (UInt8[0x7f],               (1,0,0,0,0)),   # End of ASCII range
    (UInt8[0xc0,0x80],          (1,1,0,0,0)),   # Long encoded Nul byte (Modified UTF-8, Java)
    (UInt8[0xc2,0x80],          (1,2,0,0,1)),   # \u80, beginning of Latin1 range
    (UInt8[0xc3,0xbf],          (1,2,0,0,1)),   # \uff, end of Latin1 range
    (UInt8[0xc4,0x80],          (1,4,0,0,1)),   # \u100, beginning of non-Latin1 2-byte range
    (UInt8[0xdf,0xbf],          (1,4,0,0,1)),   # \u7ff, end of non-Latin1 2-byte range
    (UInt8[0xe0,0xa0,0x80],     (1,8,0,1,0)),   # \u800, beginning of 3-byte range
    (UInt8[0xed,0x9f,0xbf],     (1,8,0,1,0)),   # \ud7ff, end of first part of 3-byte range
    (UInt8[0xee,0x80,0x80],     (1,8,0,1,0)),   # \ue000, beginning of second part of 3-byte range
    (UInt8[0xef,0xbf,0xbf],     (1,8,0,1,0)),   # \uffff, end of 3-byte range
    (UInt8[0xf0,0x90,0x80,0x80],(1,16,1,0,0)),  # \U10000, beginning of 4-byte range
    (UInt8[0xf4,0x8f,0xbf,0xbf],(1,16,1,0,0)),  # \U10ffff, end of 4-byte range
    (UInt8[0xed,0xa0,0x80,0xed,0xb0,0x80], (1,0x30,1,0,0)), # Overlong \U10000, (CESU-8)
    (UInt8[0xed,0xaf,0xbf,0xed,0xbf,0xbf], (1,0x30,1,0,0)), # Overlong \U10ffff, (CESU-8)
    (UInt16[0x0000],            (1,0,0,0,0)),   # Nul byte, beginning of ASCII range
    (UInt16[0x007f],            (1,0,0,0,0)),   # End of ASCII range
    (UInt16[0x0080],            (1,2,0,0,1)),   # Beginning of Latin1 range
    (UInt16[0x00ff],            (1,2,0,0,1)),   # End of Latin1 range
    (UInt16[0x0100],            (1,4,0,0,1)),   # Beginning of non-Latin1 2-byte range
    (UInt16[0x07ff],            (1,4,0,0,1)),   # End of non-Latin1 2-byte range
    (UInt16[0x0800],            (1,8,0,1,0)),   # Beginning of 3-byte range
    (UInt16[0xd7ff],            (1,8,0,1,0)),   # End of first part of 3-byte range
    (UInt16[0xe000],            (1,8,0,1,0)),   # Beginning of second part of 3-byte range
    (UInt16[0xffff],            (1,8,0,1,0)),   # End of 3-byte range
    (UInt16[0xd800,0xdc00],     (1,16,1,0,0)),  # \U10000, beginning of 4-byte range
    (UInt16[0xdbff,0xdfff],     (1,16,1,0,0)),  # \U10ffff, end of 4-byte range
    (UInt32[0x0000],            (1,0,0,0,0)),   # Nul byte, beginning of ASCII range
    (UInt32[0x007f],            (1,0,0,0,0)),   # End of ASCII range
    (UInt32[0x0080],            (1,2,0,0,1)),   # Beginning of Latin1 range
    (UInt32[0x00ff],            (1,2,0,0,1)),   # End of Latin1 range
    (UInt32[0x0100],            (1,4,0,0,1)),   # Beginning of non-Latin1 2-byte range
    (UInt32[0x07ff],            (1,4,0,0,1)),   # End of non-Latin1 2-byte range
    (UInt32[0x0800],            (1,8,0,1,0)),   # Beginning of 3-byte range
    (UInt32[0xd7ff],            (1,8,0,1,0)),   # End of first part of 3-byte range
    (UInt32[0xe000],            (1,8,0,1,0)),   # Beginning of second part of 3-byte range
    (UInt32[0xffff],            (1,8,0,1,0)),   # End of 3-byte range
    (UInt32[0x10000],           (1,16,1,0,0)),  # \U10000, beginning of 4-byte range
    (UInt32[0x10ffff],          (1,16,1,0,0)),  # \U10ffff, end of 4-byte range
    (UInt32[0xd800,0xdc00],     (1,0x30,1,0,0)),# Overlong \U10000, (CESU-8)
    (UInt32[0xdbff,0xdfff],     (1,0x30,1,0,0)))# Overlong \U10ffff, (CESU-8)
    @test checkstring(seq) == res
end

# Test bounds checking
@test_throws BoundsError checkstring(b"abcdef", -10)
@test_throws BoundsError checkstring(b"abcdef", 0)
@test_throws BoundsError checkstring(b"abcdef", 7)
@test_throws BoundsError checkstring(b"abcdef", 3, -10)
@test_throws BoundsError checkstring(b"abcdef", 3, 0)
@test_throws BoundsError checkstring(b"abcdef", 3, 7)
@test_throws ArgumentError checkstring(b"abcdef", 3, 1)

## UTF-8 tests

# Test for CESU-8 sequences
let ch = 0x10000
    for hichar = 0xd800:0xdbff
        for lochar = 0xdc00:0xdfff
            @test convert(UTF8String, utf8(Char[hichar, lochar]).data) == string(Char(ch))
            ch += 1
        end
    end
end

let str = UTF8String(b"this is a test\xed\x80")
    @static if VERSION < v"0.7-"
        @test next(str, 15) == ('\ufffd', 16)
    else
        @test iterate(str, 15) == ('\ufffd', 16)
    end
    @test_throws BoundsError getindex(str, 0:3)
    @test_throws BoundsError getindex(str, 17:18)
    @test_throws BoundsError getindex(str, 2:17)
    @test_throws UnicodeError getindex(str, 16:17)
    # @test string(Char(0x110000)) == "\ufffd"
    sa = SubString{ASCIIString}(LegacyStrings.ascii("This is a silly test"), 1, 14)
    s8 = convert(SubString{UTF8String}, sa)
    @test typeof(s8) == SubString{UTF8String}
    @test s8 == "This is a sill"
    @test convert(UTF8String, b"this is a test\xed\x80\x80") == "this is a test\ud000"
end

# Reverse of UTF8String
@test reverse(UTF8String("")) == ""
@test reverse(UTF8String("a")) == "a"
@test reverse(UTF8String("abc")) == "cba"
@test reverse(UTF8String("xyz\uff\u800\uffff\U10ffff")) == "\U10ffff\uffff\u800\uffzyx"
for str in (b"xyz\xc1", b"xyz\xd0", b"xyz\xe0", b"xyz\xed\x80", b"xyz\xf0", b"xyz\xf0\x80",  b"xyz\xf0\x80\x80")
    @test_throws UnicodeError reverse(UTF8String(str))
end

# Specifically check UTF-8 string whose lead byte is same as a surrogate
@test convert(UTF8String,b"\xed\x9f\xbf") == "\ud7ff"

# issue #8
@test !isempty(methods(string, Tuple{Char}))

## UTF-16 tests

let u8 = "\U10ffff\U1d565\U1d7f6\U00066\U2008a"
    u16 = utf16(u8)
    @test sizeof(u16) == 18
    @test length(u16.data) == 10 && u16.data[end] == 0
    @test length(u16) == 5
    @test utf8(u16) == u8
    @test collect(u8) == collect(u16)
    @test u8 == utf16(u16.data[1:end-1]) == utf16(copyto!(Vector{UInt8}(undef, 18), 1, reinterpret(UInt8, u16.data), 1, 18))
    @test u8 == utf16(pointer(u16)) == utf16(convert(Ptr{Int16}, pointer(u16)))
    @test_throws UnicodeError utf16(utf32(Char(0x120000)))
    @test_throws UnicodeError utf16(UInt8[1,2,3])

    @test convert(UTF16String, "test") == "test"
    @test convert(UTF16String, u16) == u16
    @test convert(UTF16String, UInt16[[0x65, 0x66] [0x67, 0x68]]) == "efgh"
    @test convert(UTF16String, Int16[[0x65, 0x66] [0x67, 0x68]]) == "efgh"
    @test map(lowercase, utf16("TEST\U1f596")) == "test\U1f596"
    @test typeof(Base.unsafe_convert(Ptr{UInt16}, utf16("test"))) == Ptr{UInt16}
end

## UTF-32 tests

let u8 = "\U10ffff\U1d565\U1d7f6\U00066\U2008a"
    u32 = utf32(u8)
    @test sizeof(u32) == 20
    @test length(u32.data) == 6 && u32.data[end] == 0
    @test length(u32) == 5
    @test utf8(u32) == u8
    @test collect(u8) == collect(u32)
    @test u8 == utf32(u32.data[1:end-1]) == utf32(copyto!(Vector{UInt8}(undef, 20), 1, reinterpret(UInt8, u32.data), 1, 20))
    @test u8 == utf32(pointer(u32)) == utf32(convert(Ptr{Int32}, pointer(u32)))
    @test_throws UnicodeError utf32(UInt8[1,2,3])
end

# issue #11551 (#11004,#10959)
function tstcvt(strUTF8::UTF8String, strUTF16::UTF16String, strUTF32::UTF32String)
    @test utf16(strUTF8) == strUTF16
    @test utf32(strUTF8) == strUTF32
    @test utf8(strUTF16) == strUTF8
    @test utf32(strUTF16) == strUTF32
    @test utf8(strUTF32)  == strUTF8
    @test utf16(strUTF32) == strUTF16
end

# Create some ASCII, UTF8, UTF16, and UTF32 strings
strAscii = LegacyStrings.ascii("abcdefgh")
strA_UTF8 = utf8(("abcdefgh\uff")[1:8])
strL_UTF8 = utf8("abcdef\uff\uff")
str2_UTF8 = utf8("abcd\uff\uff\u7ff\u7ff")
str3_UTF8 = utf8("abcd\uff\uff\u7fff\u7fff")
str4_UTF8 = utf8("abcd\uff\u7ff\u7fff\U7ffff")
strS_UTF8 = UTF8String(b"abcd\xc3\xbf\xdf\xbf\xe7\xbf\xbf\xed\xa0\x80\xed\xb0\x80")
strC_UTF8 = UTF8String(b"abcd\xc3\xbf\xdf\xbf\xe7\xbf\xbf\U10000")
strz_UTF8 = UTF8String(b"abcd\xc3\xbf\xdf\xbf\xe7\xbf\xbf\0")
strZ      = b"abcd\xc3\xbf\xdf\xbf\xe7\xbf\xbf\xc0\x80"

strA_UTF16 = utf16(strA_UTF8)
strL_UTF16 = utf16(strL_UTF8)
str2_UTF16 = utf16(str2_UTF8)
str3_UTF16 = utf16(str3_UTF8)
str4_UTF16 = utf16(str4_UTF8)
strS_UTF16 = utf16(strS_UTF8)

strA_UTF32 = utf32(strA_UTF8)
strL_UTF32 = utf32(strL_UTF8)
str2_UTF32 = utf32(str2_UTF8)
str3_UTF32 = utf32(str3_UTF8)
str4_UTF32 = utf32(str4_UTF8)
strS_UTF32 = utf32(strS_UTF8)

@test utf8(strAscii) == strAscii
@test utf16(strAscii) == strAscii
@test utf32(strAscii) == strAscii

tstcvt(strA_UTF8,strA_UTF16,strA_UTF32)
tstcvt(strL_UTF8,strL_UTF16,strL_UTF32)
tstcvt(str2_UTF8,str2_UTF16,str2_UTF32)
tstcvt(str3_UTF8,str3_UTF16,str3_UTF32)
tstcvt(str4_UTF8,str4_UTF16,str4_UTF32)

# Test converting surrogate pairs
@test utf16(strS_UTF8) == strC_UTF8
@test utf32(strS_UTF8) == strC_UTF8
@test utf8(strS_UTF16) == strC_UTF8
@test utf32(strS_UTF16) == strC_UTF8
@test utf8(strS_UTF32)  == strC_UTF8
@test utf16(strS_UTF32) == strC_UTF8

# Test converting overlong \0
@test utf8(strZ)  == strz_UTF8
@test utf16(UTF8String(strZ)) == strz_UTF8
@test utf32(UTF8String(strZ)) == strz_UTF8

# Test invalid sequences

strval(::Type{UTF8String}, dat) = dat
strval(::Union{Type{UTF16String},Type{UTF32String}}, dat) = UTF8String(dat)

for T in (UTF8String, UTF16String, UTF32String)
    # Continuation byte not after lead
    for byt in 0x80:0xbf
        @test_throws UnicodeError convert(T,  strval(T, UInt8[byt]))
    end

    # Test lead bytes
    for byt in 0xc0:0xff
        # Single lead byte at end of string
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt]))
        # Lead followed by non-continuation character < 0x80
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0]))
        # Lead followed by non-continuation character > 0xbf
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0xc0]))
    end

    # Test overlong 2-byte
    for byt in 0x81:0xbf
        @test_throws UnicodeError convert(T, strval(T, UInt8[0xc0,byt]))
    end
    for byt in 0x80:0xbf
        @test_throws UnicodeError convert(T, strval(T, UInt8[0xc1,byt]))
    end

    # Test overlong 3-byte
    for byt in 0x80:0x9f
        @test_throws UnicodeError convert(T, strval(T, UInt8[0xe0,byt,0x80]))
    end

    # Test overlong 4-byte
    for byt in 0x80:0x8f
        @test_throws UnicodeError convert(T, strval(T, UInt8[0xef,byt,0x80,0x80]))
    end

    # Test 4-byte > 0x10ffff
    for byt in 0x90:0xbf
        @test_throws UnicodeError convert(T, strval(T, UInt8[0xf4,byt,0x80,0x80]))
    end
    for byt in 0xf5:0xf7
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0x80,0x80,0x80]))
    end

    # Test 5-byte
    for byt in 0xf8:0xfb
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0x80,0x80,0x80,0x80]))
    end

    # Test 6-byte
    for byt in 0xfc:0xfd
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0x80,0x80,0x80,0x80,0x80]))
    end

    # Test 7-byte
    @test_throws UnicodeError convert(T, strval(T, UInt8[0xfe,0x80,0x80,0x80,0x80,0x80,0x80]))

    # Three and above byte sequences
    for byt in 0xe0:0xef
        # Lead followed by only 1 continuation byte
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0x80]))
        # Lead ended by non-continuation character < 0x80
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0x80,0]))
        # Lead ended by non-continuation character > 0xbf
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0x80,0xc0]))
    end

    # 3-byte encoded surrogate character(s)
    # Single surrogate
    @test_throws UnicodeError convert(T, strval(T, UInt8[0xed,0xa0,0x80]))
    # Not followed by surrogate
    @test_throws UnicodeError convert(T, strval(T, UInt8[0xed,0xa0,0x80,0xed,0x80,0x80]))
    # Trailing surrogate first
    @test_throws UnicodeError convert(T, strval(T, UInt8[0xed,0xb0,0x80,0xed,0xb0,0x80]))
    # Followed by lead surrogate
    @test_throws UnicodeError convert(T, strval(T, UInt8[0xed,0xa0,0x80,0xed,0xa0,0x80]))

    # Four byte sequences
    for byt in 0xf0:0xf4
        # Lead followed by only 2 continuation bytes
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0x80,0x80]))
        # Lead followed by non-continuation character < 0x80
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0x80,0x80,0]))
        # Lead followed by non-continuation character > 0xbf
        @test_throws UnicodeError convert(T, strval(T, UInt8[byt,0x80,0x80,0xc0]))
    end
end

# Wstring
let u8 = "\U10ffff\U1d565\U1d7f6\U00066\U2008a"
    w = wstring(u8)
    @test length(w) == 5 && utf8(w) == u8 && collect(u8) == collect(w)
    @test u8 == WString(w.data)
end

# 12268
for (fun, S, T) in ((utf16, UInt16, UTF16String), (utf32, UInt32, UTF32String))
    # AbstractString
    str = "abcd\0\uff\u7ff\u7fff\U7ffff"
    tst = SubString(convert(T,str),4)
    cmp = Char['d','\0','\uff','\u7ff','\u7fff','\U7ffff']
    cmp32 = UInt32['d','\0','\uff','\u7ff','\u7fff','\U7ffff','\0']
    cmp16 = UInt16[0x0064,0x0000,0x00ff,0x07ff,0x7fff,0xd9bf,0xdfff,0x0000]
    x = fun(tst)
    cmpx = (S == UInt16 ? cmp16 : cmp32)
    @test typeof(tst) == SubString{T}
    @test convert(T, tst) == str[4:end]
    @test Vector{Char}(x) == cmp
    # Vector{T} / Array{T}
    @test convert(Vector{S}, x) == cmpx
    @test convert(Array{S}, x) == cmpx
    # Embedded nul checking
    @test Base.containsnul(x)
    @test Base.containsnul(tst)
    # map
    @test_throws UnicodeError map(islowercase, x)
    @test_throws ArgumentError map(islowercase, tst)
    # SubArray conversion
    subarr = view(cmp, 1:6)
    @test convert(T, subarr) == str[4:end]
end

# Char to UTF32String
@test utf32('\U7ffff') == utf32("\U7ffff")
@test convert(UTF32String, '\U7ffff') == utf32("\U7ffff")

@test isvalid(UTF32String, Char['d','\uff','\u7ff','\u7fff','\U7ffff'])
@test reverse(utf32("abcd \uff\u7ff\u7fff\U7ffff")) == utf32("\U7ffff\u7fff\u7ff\uff dcba")

# Test pointer() functions
let str = LegacyStrings.ascii("this ")
    u8  = utf8(str)
    u16 = utf16(str)
    u32 = utf32(str)
    pa  = pointer(str)
    p8  = pointer(u8)
    p16 = pointer(u16)
    p32 = pointer(u32)
    @test typeof(pa) == Ptr{UInt8}
    @test unsafe_load(pa,1) == 0x74
    @test typeof(p8) == Ptr{UInt8}
    @test unsafe_load(p8,1) == 0x74
    @test typeof(p16) == Ptr{UInt16}
    @test unsafe_load(p16,1) == 0x74
    @test typeof(p32) == Ptr{UInt32}
    @test unsafe_load(p32,1) == 0x74
    pa  = pointer(str, 2)
    p8  = pointer(u8,  2)
    p16 = pointer(u16, 2)
    p32 = pointer(u32, 2)
    @test typeof(pa) == Ptr{UInt8}
    @test unsafe_load(pa,1) == 0x68
    @test typeof(p8) == Ptr{UInt8}
    @test unsafe_load(p8,1) == 0x68
    @test typeof(p16) == Ptr{UInt16}
    @test unsafe_load(p16,1) == 0x68
    @test typeof(p32) == Ptr{UInt32}
    @test unsafe_load(p32,1) == 0x68
    sa  = SubString{ASCIIString}(str, 3, 5)
    s8  = SubString{UTF8String}(u8,   3, 5)
    s16 = SubString{UTF16String}(u16, 3, 5)
    s32 = SubString{UTF32String}(u32, 3, 5)
    pa  = pointer(sa)
    p8  = pointer(s8)
    p16 = pointer(s16)
    p32 = pointer(s32)
    @test typeof(pa) == Ptr{UInt8}
    @test unsafe_load(pa,1) == 0x69
    @test typeof(p8) == Ptr{UInt8}
    @test unsafe_load(p8,1) == 0x69
    @test typeof(p16) == Ptr{UInt16}
    @test unsafe_load(p16,1) == 0x69
    @test typeof(p32) == Ptr{UInt32}
    @test unsafe_load(p32,1) == 0x69
    pa  = pointer(sa, 2)
    p8  = pointer(s8,  2)
    p16 = pointer(s16, 2)
    p32 = pointer(s32, 2)
    @test typeof(pa) == Ptr{UInt8}
    @test unsafe_load(pa,1) == 0x73
    @test typeof(p8) == Ptr{UInt8}
    @test unsafe_load(p8,1) == 0x73
    @test typeof(p16) == Ptr{UInt16}
    @test unsafe_load(p16,1) == 0x73
    @test typeof(p32) == Ptr{UInt32}
    @test unsafe_load(p32,1) == 0x73
end

@test isvalid(Char['f','o','o','b','a','r'])


## Repeat strings ##

# Base Julia issue #7764
let
    rs = RepString("foo", 2)
    @test length(rs) == 6
    @test sizeof(rs) == 6
    @test isascii(rs)
    @test convert(RepString, "foobar") == "foobar"
    @test convert(RepString, "foobar") isa RepString

    srep = RepString("Σβ",2)
    s="Σβ"
    ss=SubString(s,1,lastindex(s))

    @test ss^2 == "ΣβΣβ"
    @test RepString(ss,2) == "ΣβΣβ"

    @test lastindex(srep) == 7

    @static if VERSION < v"0.7-"
        @test next(srep, 3) == ('β',5)
        @test next(srep, 7) == ('β',9)
    else
        @test iterate(srep, 3) == ('β',5)
        @test iterate(srep, 7) == ('β',9)
    end

    @test srep[7] == 'β'
    @static if VERSION < v"0.7.0-DEV.2924"
        @test_throws BoundsError srep[8]
    else
        @test_throws StringIndexError srep[8]
    end
end


## Reverse strings ##

let
    rs = RevString("foobar")
    @test length(rs) == 6
    @test sizeof(rs) == 6
    @test isascii(rs)

    # Base issue #4586
    @test rsplit(RevString("ailuj"),'l') == ["ju","ia"]
    @test parse(Float64,RevString("64")) === 46.0

    # reverseind
    for prefix in ("", "abcd", "\U0001d6a4\U0001d4c1", "\U0001d6a4\U0001d4c1c", " \U0001d6a4\U0001d4c1")
        for suffix in ("", "abcde", "\U0001d4c1β\U0001d6a4", "\U0001d4c1β\U0001d6a4c", " \U0001d4c1β\U0001d6a4")
            for c in ('X', 'δ', '\U0001d6a5')
                s = convert(String, string(prefix, c, suffix))
                rs = RevString(s)
                r = reverse(s)
                @test r == rs
                ri = something(findfirst(isequal(c), r), 0)
                @test c == s[reverseind(s, ri)] == r[ri]
            end
        end
    end
end


# length

for s in ["", "a", "â", "Julia", "줄리아"]
    for u in [LegacyStrings.ascii, utf8, utf16, utf32]
        u == LegacyStrings.ascii && !isascii(s) && continue
        @test length(s) == length(u(s))
    end
end


## isascii ##

for s in ["", "a", "â", "abcde", "abçde"]
    isascii(s) && @test isascii(LegacyStrings.ascii(s))
    @test isascii(s) == isascii(RepString(s, 3))
    @test isascii(RepString(s, 0))
    @test isascii(s) == isascii(RevString(s))
end


## codeunit, codeunits and ncodeunits ##

function test_codeunit(s0, s, to_str)
    cu = codeunits(s)
    @test length(cu) == ncodeunits(s)
    isempty(s) || @test codeunit(s, 1) isa codeunit(s)
    @test_throws BoundsError cu[0]
    @test_throws BoundsError cu[end+1]
    @test s0 == to_str(collect(cu))
end

for s0 in ["", "Julia = Juliet", "Julia = Ιουλιέτα = 朱丽叶 ≠ 𐍈"]
    for u in [identity, LegacyStrings.ascii, utf8, utf16, utf32]
        u == LegacyStrings.ascii && !isascii(s0) && continue

        s1 = u(s0)

        # function to convert codeunits to the type of s1
        to_str = u === identity ? String : (cu -> convert(typeof(s1), cu))

        # ASCIIString, UTF8String, UTF16String, UTF32String
        test_codeunit(s0, s1, to_str)

        # RepString
        for k in [0, 1, 3]
            s2 = RepString(s1, k)
            test_codeunit(s0^k, s2, to_str)
        end

        # RevString
        s2 = RevString(s1)
        test_codeunit(reverse(s0), s2, to_str)
    end
end


# construction of strings via AbstractVector

for s0 in ["", "Julia = Juliet", "Julia = Ιουλιέτα = 朱丽叶 ≠ 𐍈"]
    for u in [LegacyStrings.ascii, utf8, utf16, utf32]
        u == LegacyStrings.ascii && !isascii(s0) && continue
        s = u(s0)
        cu = codeunits(s)
        @test s == u(cu)
        @test s == u(view(cu, 1:length(cu)))
    end
end
