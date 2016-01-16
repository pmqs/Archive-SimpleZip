#!perl6 
 
use v6; 
use lib 'lib'; 
 
use Test; 
 
plan 9; 

use Archive::SimpleZip;

my $outfile = "/tmp/test.zip" ;

unlink $outfile;

ok ! $outfile.IO.e, "$outfile does not exists";

my $zip = SimpleZip.new($outfile);
isa-ok $zip, SimpleZip;

ok $zip.add("abcde", :name<fred>), "add ok";
ok $zip.add("def", :name<joe>, :method(Zip-CM-Store), :stream), "add ok";
ok $zip.close(), "closed";

ok $outfile.IO.e, "$outfile exists";


my Blob $data .= new();
my $zip2 = SimpleZip.new($data);
isa-ok $zip2, SimpleZip;
ok $zip2.add("abcde", :name<fred>), "add ok";
ok $zip2.close(), "closed";

#unlink $outfile;

done-testing();

