import Foundation
import Darwin

// Each explicit Run command gets its own process group, so Stop can interrupt
// the shell and its ordinary children without signalling the app's group.
guard CommandLine.arguments.count == 2 else { exit(64) }
if setsid() < 0 && getpgrp() != getpid() { perror("setsid"); exit(70) }
var arguments = [strdup("zsh"), strdup("-c"), strdup(CommandLine.arguments[1]), nil]
arguments.withUnsafeMutableBufferPointer { buffer in
    _ = execv("/bin/zsh", buffer.baseAddress!)
}
perror("execv")
exit(127)
