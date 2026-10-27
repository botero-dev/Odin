#+build linux
#+private
package thread

import "core:sys/posix"
import "core:c"

_MAX_PTHREAD_NAME_LENGTH :: 16

// Bionic folds the pthread symbols into libc and no longer ships a standalone
// libpthread (removed in API 21), so `system:pthread` makes the linker fail with
// "unable to find library -lpthread" for the Android subtarget.
when ODIN_PLATFORM_SUBTARGET == .Android {
	foreign import pthread "system:c"
} else {
	foreign import pthread "system:pthread"
}

foreign pthread {
	pthread_getname_np :: proc(thread: posix.pthread_t, name: [^]u8, len: c.size_t) -> posix.Errno ---
	pthread_setname_np :: proc(thread: posix.pthread_t, name: [^]u8) -> posix.Errno ---
}
