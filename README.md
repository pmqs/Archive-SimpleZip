# Archive::SimpleZip

Raku (Perl6) module to write Zip archives.

![Linux Build](https://github.com/pmqs/Archive-SimpleZip/actions/workflows/linux.yml/badge.svg)
![MacOS Build](https://github.com/pmqs/Archive-SimpleZip/actions/workflows/macos.yml/badge.svg)
![Windows Build](https://github.com/pmqs/Archive-SimpleZip/actions/workflows/windows.yml/badge.svg)

## Synopsis


```
use Archive::SimpleZip;

# Create a zip file in the filesystem
my $z = SimpleZip.new: "mine.zip";

# Add a file to the zip archive
$z.add: "/some/file.txt";

# Add multiple files in one step
# the 'add' method will consume anything that is an Iterable
$z.add: @list_of_files;

# change the compression method to STORE
$z.add: 'somefile', :method(Zip-CM-Store);

# add knows what to do with IO::Glob
use IO::Glob;
$z.add: glob("*.c");

# add a file, but call it something different in the zip file
$z.add: "/some/file.txt", :name<better-name>;

# algorithmically rename the files by passing code to the name option
# in this instance chage file extension from '.tar.gz' to ;.tgz'
$z.add: @list_of_files, :name( *.subst(/'.tar.gz' $/, '.tgz') ), :method(Zip-CM-Store);

# when used in a method chain it will accept an Iterable and output a Seq of filenames

# add all files matched by IO::Glob
glob("*.c").dir.$z ;

# or like this
glob("*.c").$z ;

# contrived example
glob("*.c").grep( ! *.d).$z.uc.sort.say;

# Create a zip entry from a string/blob

$z.create(:name<data1>, "payload data here");
$z.create(:name<data2>, Blob.new([2,4,6]));

# Drop a filehandle into the zip archive
my $handle = "/another/file".IO.open;
$z.create("data3", $handle);

# use Associative interface to call 'create' behind the secenes
$z<data4> = "more payload";

# can also use Associative interface to add a file from the filesystem
# just make sure it is of type IO
$z<data5> = "/real/file.txt".IO;

# or a filehandle
$z<data5> = $handle;

# create a directory
$z.mkdir: "dir1";

$z.close;
```


## Description

Simple write-only interface to allow creation of Zip files.

See the full documentation at the end of the file `lib/Archive/SimpleZip.rakumod`.

## Installation

Assuming you have a working Rakudo installation you should be able to install this with `zef` :

```
# From the source directory

zef install .

# Remote installation

zef install Archive::SimpleZip
```
## Support

Suggestions/patches are welcome at [Archive-SimpleZip](https://github.com/pmqs/Archive-SimpleZip)

## License

Please see the LICENSE file in the distribution

(C) Paul Marquess 2016-2023
