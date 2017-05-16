
unit module LexFile ;


class LexF
{
    my $index = '00000' ;
    has @!filenames ;
    has $!filename ;

    multi submethod BUILD()
    {
#        $!filename = 'tst' ~ $*PID ~ 'X' ~ $index ~ '.tmp' ;
#        $!filename .= IO;
#        chmod 0o777, $!filename ;
#        unlink $!filename ;
#        #push @created, $!filename;
#        #push @!filenames, $!filename;
#        ++ $index ;
    }

    method get(Int $count=1)
    {
        my @created ;
        
        for ^$count 
        {
            my $filename = 'tst' ~ $*PID ~ 'X' ~ $index ~ '.tmp' ;
            $filename .= IO;
            chmod 0o777, $filename ;
            unlink $filename ;
            push @created, $filename;
            push @!filenames, $filename;
            ++ $index ;
        }
        
        return @created;
    }

    method Str
    {
        return $!filename;
    }

    LEAVE
    {
        say "LEAVE ";
        #chmod 0o777, $!filename ;
        #unlink $!filename ;

        #for @!filenames -> $file
        #{
        #    chmod 0o777, $file ;
        #    unlink $file ;
        #}
    }
}

my $index = '00000' ;
my @filenames ;

sub lex-file is export
{
    return LexF.new ;

#    my IO $filename will leave { say "leave"; unlink($_) } 
#                 = 'tst' ~ $*PID ~ 'X' ~ $index ~ '.tmp' 
#    #$filename .= IO;
#    chmod 0o777, $filename ;
#    unlink $filename ;
#    #push @created, $filename;
#    push @filenames, $filename;
#    ++ $index ;
#    return $filename will leave { say "leave"; unlink($_) } ;
}


END
{
        for @filenames -> $file
        {
            chmod 0o777, $file ;
            unlink $file ;
        }
}

