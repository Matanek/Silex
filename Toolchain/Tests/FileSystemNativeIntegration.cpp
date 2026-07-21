#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include "../../Library/STD/@Native/FileSystem.cpp"

namespace {

namespace fs = std::filesystem;

template <typename Result>
void release(Result& result) {
    std::free(result.detailBytes);
}

SilexFileSystemOperationResult removePath(const std::string& path, bool directory) {
    SilexFileSystemOperationResult result{};
    silexNative_STD_FileSystem_native_remove(
        path.data(), static_cast<std::int64_t>(path.size()), directory, &result
    );
    return result;
}

SilexFileSystemMetadataResult metadata(const std::string& path, bool follow) {
    SilexFileSystemMetadataResult result{};
    silexNative_STD_FileSystem_native_metadata(
        path.data(), static_cast<std::int64_t>(path.size()), follow, &result
    );
    return result;
}

void collectEntry(void* context, std::int64_t first, std::int64_t second) {
    auto& values = *static_cast<std::vector<std::pair<std::int64_t, std::string>>*>(context);
    if (first != 0) {
        values.emplace_back(first, std::string{});
        values.back().second.reserve(static_cast<std::size_t>(second));
        return;
    }
    values.back().second.push_back(static_cast<char>(second));
}

} // namespace

int main(int argumentCount, char** arguments) {
    if (argumentCount != 2) return 2;
    const fs::path root = arguments[1];
    std::error_code cleanupError;
    fs::remove_all(root, cleanupError);
    fs::create_directories(root);

    const auto target = root / "target.bin";
    const auto victim = root / "victim.bin";
    const auto link = root / "link.bin";
    const auto loopA = root / "loop-a";
    const auto loopB = root / "loop-b";
    std::ofstream(target, std::ios::binary) << "abc";
    std::ofstream(victim, std::ios::binary) << "victim";
    fs::create_symlink(target.filename(), link);

    auto followed = metadata(target.string(), true);
    auto linkMetadata = metadata(link.string(), false);
    if (!followed.succeeded || followed.fileKind != 1 || followed.size != 3 ||
        !linkMetadata.succeeded || linkMetadata.fileKind != 3 || linkMetadata.size != 0) return 3;
    release(followed);
    release(linkMetadata);

    auto refusedDirectoryRemoval = removePath(link.string(), true);
    if (refusedDirectoryRemoval.succeeded || refusedDirectoryRemoval.errorKind != 8 ||
        !fs::is_symlink(link) || !fs::exists(target)) return 4;
    release(refusedDirectoryRemoval);

    SilexFileSystemOperationResult copied{};
    silexNative_STD_FileSystem_native_copy_file(
        target.string().data(), static_cast<std::int64_t>(target.string().size()),
        link.string().data(), static_cast<std::int64_t>(link.string().size()), true, &copied
    );
    if (!copied.succeeded || fs::is_symlink(link) || fs::file_size(link) != 3 ||
        fs::file_size(victim) != 6) return 5;
    release(copied);

    fs::create_symlink(loopB.filename(), loopA);
    fs::create_symlink(loopA.filename(), loopB);
    SilexFileSystemPathResult canonical{};
    const auto loopText = loopA.string();
    silexNative_STD_FileSystem_native_canonicalize(
        loopText.data(), static_cast<std::int64_t>(loopText.size()), &canonical
    );
    if (canonical.succeeded) return 6;
    std::free(canonical.pathBytes);
    release(canonical);

    std::vector<std::pair<std::int64_t, std::string>> entries;
    SilexFileSystemOperationResult listed{};
    const auto rootText = root.string();
    silexNative_STD_FileSystem_native_visit_entries(
        rootText.data(), static_cast<std::int64_t>(rootText.size()),
        collectEntry, &entries, &listed
    );
    if (!listed.succeeded || entries.empty()) return 7;
    for (std::size_t index = 1; index < entries.size(); ++index) {
        if (byteLess(entries[index].second, entries[index - 1].second)) return 8;
    }
    release(listed);

#if !defined(_WIN32)
    const std::string simulatedInvalidName = "invalid-\xff";
    if (validUtf8(simulatedInvalidName)) return 9;
#endif

    fs::remove_all(root, cleanupError);
    return 0;
}
