# Archive::SimpleZip

Raku (Perl6) module to write Zip archives.

[ ![Linux Build & Test](https://github.com/pmqs/Archive-SimpleZip/workflows/linux.yml/badge.svg) ](https://github.com/pmqs/Archive-SimpleZip/actions)
[ ![MacOS Build & Test](https://github.com/pmqs/Archive-SimpleZip/workflows/macos.yml/badge.svg) ](https://github.com/pmqs/Archive-SimpleZip/actions)
[ ![Windows Build & Test](https://github.com/pmqs/Archive-SimpleZip/workflows/windows.yml/badge.svg) ](https://github.com/pmqs/Archive-SimpleZip/actions)

## Synopsis


```
use Archive::SimpleZip;

# Create a zip file in filesystem
my $z = SimpleZip.new("mine.zip");

# Add a file to the zip archive
$z.add("somefile.txt");

# Add multiple files in one step
# will consume anything that is an Iterable
$z.add(@list_of_files);

use IO::Glob;
$z.add(glob("*.c"));

# when used in a method chain it will accept an Iterable and output a Seq

glob("*.c").map().sort.$z.uc.say ;

# Create a zip entry from a string/blob

$z.create(:name<data1>, "payload data here");
$z.create(:name<data2>, Blob.new([2,4,6]));

# Drop a filehandle into the zip archive
my $handle = "some file".IO.open;
$z.create("data3", $handle);

# create a directory
$z.mkdir: "dir1";

$z.close();
```


## Description

Simple write-only interface to allow creation of Zip files.

Please note - this is module is a prototype. The interface will change.

## Support

Suggestions/patches are welcomed at [Archive-SimpleZip](https://github.com/pmqs/Archive-SimpleZip)

## License

Please see the LICENSE file in the distribution

(C) Paul Marquess 2016-2023
