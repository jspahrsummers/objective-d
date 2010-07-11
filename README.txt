Objective-D 0.1b1
by Justin Spahr-Summers
-----------------------

This is a mostly-undocumented beta release of the Objective-D preprocessor and
runtime. Parsing D code is not feature-complete and probably somewhat buggy,
though all documented Objective-D constructs should work. Please feel free to
report any bugs to the issue tracker on Google Code:
	<http://code.google.com/p/objective-d/issues/>

See Objective-D.txt for a list of Objective-D language features.

=== Compilation ===

Compilation has only been officially tested on Mac OS X. The Makefile included
in the distribution reflects this, though it should work, with some simple
modifications, on any system running dmd. Other D compilers are not officially
supported, though the Makefile and source might be made to work with them.
Compilation and installation follows standard "make" usage:

	cd folder/with/objective-d
	make
	make check
	sudo make install

By default, the Objective-D compiler and runtime are built with compatibility
for Objective-C. On systems other than Mac OS X, this is very likely to cause
problems. Disabling the Objective-C compatibility layer entirely is relatively
simple:

	1. Open the top level Makefile.
	2. Remove "-version=objc_compat" from the DFLAGS listed to disable support
	   in the Objective-D runtime.
	2. Remove all the D_OBJCFLAGS so that the linker does not try to include
	   libraries and frameworks specific to Objective-C.
