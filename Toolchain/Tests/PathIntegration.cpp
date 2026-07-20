#include <cassert>
#include <string_view>

#include "../../Library/STD/@Native/PathCore.hpp"

namespace {

void expectText(SilexPath::Result result, std::string_view expected) {
    assert(result.succeeded);
    assert(result.present);
    assert(result.text == expected);
}

void expectAbsent(SilexPath::Result result) {
    assert(result.succeeded);
    assert(!result.present);
}

void expectInvalid(SilexPath::Result result) {
    assert(!result.succeeded);
    assert(!result.detail.empty());
}

} // namespace

int main() {
    expectText(SilexPath::normalize("", false), ".");
    expectText(SilexPath::normalize("a//./b/../c", false), "a/c");
    expectText(SilexPath::normalize("../../a", false), "../../a");
    expectText(SilexPath::normalize("/../../a//b", false), "/a/b");
    expectText(SilexPath::normalize("a\\b", false), "a\\b");
    assert(SilexPath::isAbsolute("/a", false).boolean);
    assert(!SilexPath::isAbsolute("a", false).boolean);

    expectText(SilexPath::normalize("C:\\work\\.\\src\\..\\Main.sx", true), "C:/work/Main.sx");
    expectText(SilexPath::normalize("c:/../../work", true), "c:/work");
    expectText(SilexPath::normalize("//server/share/a//../b", true), "//server/share/b");
    expectText(SilexPath::normalize("relative\\a\\..\\b", true), "relative/b");
    assert(SilexPath::isAbsolute("C:/a", true).boolean);
    assert(SilexPath::isAbsolute("\\\\server\\share\\a", true).boolean);
    assert(!SilexPath::isAbsolute("a/b", true).boolean);

    expectInvalid(SilexPath::validate(std::string{"a\0b", 3}, false));
    expectInvalid(SilexPath::validate("C:relative", true));
    expectInvalid(SilexPath::validate("1:/invalid", true));
    expectInvalid(SilexPath::validate("//server", true));
    expectInvalid(SilexPath::validate("///server/share", true));
    expectInvalid(SilexPath::validate("\\\\?\\C:\\work", true));
    expectInvalid(SilexPath::validate("\\\\.\\device", true));
    expectInvalid(SilexPath::validate("/rooted", true));

    expectText(SilexPath::join("a/b", "../c", false), "a/c");
    expectText(SilexPath::join("a/b", "/c", false), "/c");
    expectText(SilexPath::join("C:/a", "D:\\b", true), "D:/b");
    expectInvalid(SilexPath::join("C:bad", "child", true));
    expectInvalid(SilexPath::join("C:/base", "//server", true));

    expectText(SilexPath::parent("a/b.txt", false), "a");
    expectText(SilexPath::parent("a", false), ".");
    expectAbsent(SilexPath::parent("/", false));
    expectAbsent(SilexPath::parent("C:/", true));
    expectAbsent(SilexPath::parent("//server/share/", true));
    expectText(SilexPath::parent("//server/share/a", true), "//server/share/");

    expectText(SilexPath::name("a/archive.tar.gz", false), "archive.tar.gz");
    expectAbsent(SilexPath::name("/", false));
    expectText(SilexPath::stem("a/archive.tar.gz", false), "archive.tar");
    expectText(SilexPath::extension("a/archive.tar.gz", false), "gz");
    expectText(SilexPath::stem(".profile", false), ".profile");
    expectAbsent(SilexPath::extension(".profile", false));
    expectText(SilexPath::stem("file", false), "file");
    expectAbsent(SilexPath::extension("file", false));
}
