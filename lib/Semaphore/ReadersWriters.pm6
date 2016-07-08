#`{{
  use Semaphore::ReadersWriters;

  my Semaphore::ReadersWriters $rw .= new;
  $rw.add-mutex-names('shv');
  my $shared-var = 10;

  # After creating threads ...
  # Some writer thread
  $rw.writer( 'shv', {$shared-var += 2});

  # Some reader thread
  say 'Shared var is ', $rw.reader( 'shv', {$shared-var;});
}}

class Semaphore::ReadersWriters:ver<0.1.0>:auth<git@github.com:MARTIMM> {

  # Using state instead of has or my will have a scope over all
  # objects of this class, state will also be initialized only
  # once and BUILD is not necessary.
  state Hash $semaphores = {};
  state Semaphore $s-mutex = Semaphore.new(1);

  constant C-RW-TYPE                            = 0;
  constant C-READSTRUCT-LOCK                    = 1; # read count lock
  constant C-READERS-LOCK                       = 2; # block readers
  constant C-READERS-COUNT                      = 3; # count readers
  constant C-WRITESTRUCT-LOCK                   = 4; # write count lock
  constant C-WRITERS-LOCK                       = 5; # block writers
  constant C-WRITERS-COUNT                      = 6; # writer count

  subset RWPatternType of Int where 1 <= $_ <= 3;
  constant C-RW-READERPRIO is export            = 1;
  constant C-RW-NOWRITERSTARVE is export        = 2;
  constant C-RW-WRITERPRIO is export            = 3;

  #-----------------------------------------------------------------------------
  method add-mutex-names (
    *@snames,
    RWPatternType :$RWPatternType = C-RW-WRITERPRIO
  ) {

    $s-mutex.acquire;
    for @snames -> $sname {
    
      # Make an array of each entry. [0] is a readers semaphore with a readers
      # counter([1]). Second pair is for writers at [2] and [3].
      $semaphores{$sname} = [
        $RWPatternType,         # pattern type
        Semaphore.new(1), Semaphore.new(1), 0,    # readers semaphores and count
        Semaphore.new(1), Semaphore.new(1), 0     # writers semaphores and count
      ] unless $semaphores{$sname}:exists;
    }
    $s-mutex.release;
  }

  #-----------------------------------------------------------------------------
  method rm-mutex-names (*@snames) {

    $s-mutex.acquire;
    for @snames -> $sname {
      $semaphores{$sname}:delete if $semaphores{$sname}:exists;
    }
    $s-mutex.release;
  }

  #-----------------------------------------------------------------------------
  method get-mutex-names () {

    $s-mutex.acquire;
    my @names = $semaphores.keys;
    $s-mutex.release;

    return @names;
  }

  #-----------------------------------------------------------------------------
  method reader ( Str:D $sname, Block $code) {

    # Check if structure of key is defined
    $s-mutex.acquire;
    my Bool $has-key = $semaphores{$sname}:exists;
    $s-mutex.release;
    return fail("mutex name '$sname' does not exist") unless $has-key;

say "R hold ws";
    # if writers are busy then wait,
    $semaphores{$sname}[C-WRITERS-LOCK].acquire;
say "R hold ws continue";

    self!lock( $sname, :is-reader);

say "R release ws";
    # signal writers queue
    $semaphores{$sname}[C-WRITERS-LOCK].release;

say "R run code";
    my $r = &$code();

    self!unlock( $sname, :is-reader);

    $r;
  }

  #-----------------------------------------------------------------------------
  method writer ( Str:D $sname, Block $code) {

    # Check if structure of key is defined
    $s-mutex.acquire;
    my Bool $has-key = $semaphores{$sname}:exists;
    $s-mutex.release;
    return fail("mutex name '$sname' does not exist") unless $has-key;

    self!lock( $sname, :!is-reader);

say "W block writers";
    # Block other writers
    $semaphores{$sname}[C-READERS-LOCK].acquire;
say "W block writers continue";

say "W run code";
    my $r = &$code();

say "W accept other writers";
    $semaphores{$sname}[C-READERS-LOCK].release;

    self!unlock( $sname, :!is-reader);

    $r;
  }

  #-----------------------------------------------------------------------------
  method !lock ( Str:D $sname, Bool:D :$is-reader ) {

say "{$is-reader ?? 'R' !! 'W'} lock";
    # hold if this is the first writer
    if $is-reader {
      $semaphores{$sname}[C-READSTRUCT-LOCK].acquire;
      $semaphores{$sname}[C-READERS-LOCK].acquire
        if ++$semaphores{$sname}[C-READERS-COUNT] == 1;
      $semaphores{$sname}[C-READSTRUCT-LOCK].release;
    }
    
    else {
      $semaphores{$sname}[C-WRITESTRUCT-LOCK].acquire;
      $semaphores{$sname}[C-WRITERS-LOCK].acquire
        if ++$semaphores{$sname}[C-WRITERS-COUNT] == 1;
      $semaphores{$sname}[C-WRITESTRUCT-LOCK].release;
    }
say "{$is-reader ?? 'R' !! 'W'} release";
  }

  #-----------------------------------------------------------------------------
  method !unlock ( Str:D $sname, Bool:D :$is-reader ) {

say "{$is-reader ?? 'R' !! 'W'} unlock";
    if $is-reader {
      $semaphores{$sname}[C-READSTRUCT-LOCK].acquire;
      $semaphores{$sname}[C-READERS-LOCK].release
        if --$semaphores{$sname}[C-READERS-COUNT] == 0;
      $semaphores{$sname}[C-READSTRUCT-LOCK].release;
    }
    
    else {
      $semaphores{$sname}[C-WRITESTRUCT-LOCK].acquire;
      $semaphores{$sname}[C-WRITERS-LOCK].release
        if --$semaphores{$sname}[C-WRITERS-COUNT] == 0;
      $semaphores{$sname}[C-WRITESTRUCT-LOCK].release;
    }
say "{$is-reader ?? 'R' !! 'W'} unlocked";
  }
}


