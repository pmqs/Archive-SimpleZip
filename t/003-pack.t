#!perl6 
 
use v6; 
use lib 'lib'; 
use lib 't'; 

use experimental :pack;

 
use Test; 
 
plan 15; 

use Packed; 

class Inner
{
    has int8  $.i8  ;
    has int16 $.i16 ;
    has int32 $.i32 ;
    has int64 $.i64 ;
    #has Blob  $.blob;
}

class Outer
{
    has int8 $.before;
    has Inner $.inner ;
    has int8 $.after;
}

my Blob $data ;
$data  = pack("C", 35);
$data ~= pack("v", 2456);
$data ~= pack("V", 8765);
$data ~= pack("VV", 1289, 0);
    #$data ~= "abcd".encode;

my $got = unpacker(Inner, $data);

isa-ok $got, Inner;    

is $got.i8, 35;
is $got.i16, 2456;
is $got.i32, 8765;
is $got.i64, 1289;
#is $got.blob.decode, "abcd";

my Blob $data2;
$data2  = pack("C", 4);
$data2 ~= $data ;
$data2 ~= pack("C", 6);

my $got2 = unpacker(Outer, $data2);
isa-ok $got2, Outer;    

is $got2.before, 4;
isa-ok $got2.inner, Inner;    
is $got2.inner.i8, 35;
is $got2.inner.i16, 2456;
is $got2.inner.i32, 8765;
is $got2.inner.i64, 1289;
#is $got2.inner.blob.decode, "abcd";
is $got2.after, 6;

is-deeply unpacker(Inner, marshal($got)), $got;
is-deeply unpacker(Outer, marshal($got2)), $got2;
