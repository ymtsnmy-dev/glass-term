import Foundation

func vtermSmokeTest() {
    let vt = vterm_new(24, 80)
    vterm_free(vt)
}
