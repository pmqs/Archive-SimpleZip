# Archive::SimpleZip

Raku (Perl6) module to write Zip archives.

[ ![Raku Test](https://github.com/pmqs/Archive-SimpleZip/workflows/Raku%20Test/badge.svg) ](https://github.com/pmqs/Archive-SimpleZip/actions)
[![Build Status](https://travis-ci.com/pmqs/Archive-SimpleZip.svg?branch=master)](https://travis-ci.com/pmqs/Archive-SimpleZip)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/pmqs/Archive-SimpleZip?svg=true)](https://ci.appveyor.com/project/pmqs/Archive-SimpleZip)



## Synopsis


```
use Archive::SimpleZip;

# Create a zip file in filesystem
my $z = SimpleZip.new("mine.zip");

# Add a file to the zip archive
$z.add("somefile.txt");

# Add a Blob/String
$z.add("payload data here", :name<data1>);
$z.add(Blob.new([2,4,6]), :name<data2>);

# Drop a filehandle into the zip archive
my $handle = "some file".IO.open;
$z.add($handle, :name<data3>);

# Add multiple files in one step

$z.add(@list_of_files);

use IO::Glob;
$z.add(glob("*.c"));

$z.close();
```


## Description

Simple write-only interface to allow creation of Zip files.

Please note - this is module is a prototype. The interface will change.

## Support

Suggestions/patches are welcomed at [Archive-SimpleZip](https://github.com/pmqs/Archive-SimpleZip)

## Licence

Please see the LICENCE file in the distribution

(C) Paul Marquess 2016-2023
