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

  constant C-READERS-LOCK       = 0;
  constant C-READERS-COUNT      = 1;
  constant C-WRITERS-LOCK       = 2;
  constant C-WRITERS-COUNT      = 3;


  #-----------------------------------------------------------------------------
  method add-mutex-names (*@snames) {

    $s-mutex.acquire;
    for @snames -> $sname {
    
      # Make an array of each entry. [0] is a readers semaphore with a readers
      # counter([1]). Second pair is for writers at [2] and [3].
      $semaphores{$sname} = [ Semaphore.new(1), 0, Semaphore.new(1), 0]
        unless $semaphores{$sname}:exists;
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
  method reader ( Str $sname, Block $code) {

    my Bool $no-name = False;

    $s-mutex.acquire;
    if $semaphores{$sname}:exists {

      # if writers are busy then wait, can be inside because we release also
      # before release of mutex
      $semaphores{$sname}[C-WRITERS-LOCK].acquire;

      # hold when we are the first reader
      $semaphores{$sname}[C-READERS-LOCK].acquire
        if ++$semaphores{$sname}[C-READERS-COUNT] == 1;

      # signal writers queue
      $semaphores{$sname}[C-WRITERS-LOCK].release;
    }

    else {
      $no-name = True;
    }

    $s-mutex.release;
    return fail("mutex name '$sname' does not exist") if $no-name;

    my $r = &$code();

    $s-mutex.acquire;
    # last reader will release access
    $semaphores{$sname}[C-READERS-LOCK].release
      if --$semaphores{$sname}[C-READERS-COUNT] == 0;
    $s-mutex.release;

    $r;
  }


  #-----------------------------------------------------------------------------
  method writer ( Str $sname, Block $code) {

    my Bool $no-name = False;

    $s-mutex.acquire;
    if $semaphores{$sname}:exists {

      # hold if this is the first writer
      $semaphores{$sname}[C-WRITERS-LOCK].acquire
        if ++$semaphores{$sname}[C-WRITERS-COUNT] == 1;
    }

    else {
      $no-name = True;
    }

    $s-mutex.release;
    return fail("mutex name '$sname' does not exist") if $no-name;

    # wait for all readers to leave, can be outside mutex because no changes
    $semaphores{$sname}[C-READERS-LOCK].acquire;

    my $r = &$code();

    $semaphores{$sname}[C-READERS-LOCK].release;

    $s-mutex.acquire;
    $semaphores{$sname}[C-WRITERS-LOCK].release
      if --$semaphores{$sname}[C-WRITERS-COUNT] == 0;
    $s-mutex.release;

    $r;
  }
}

