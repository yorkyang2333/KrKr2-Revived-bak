#include <filesystem>
#include <string>
#include <vector>

#include <mach-o/dyld.h>
#include <sys/time.h>
#include <unistd.h>

#include "Platform.h"

namespace {

std::string TVPGetDefaultFileDirImpl() {
    char buffer[PATH_MAX];
    uint32_t size = sizeof(buffer);
    if(_NSGetExecutablePath(buffer, &size) != 0) {
        return {};
    }

    char resolved[PATH_MAX];
    if(realpath(buffer, resolved) != nullptr) {
        return { resolved };
    }

    return { buffer };
}

} // namespace

bool TVPDeleteFile(const std::string &filename) {
    return unlink(filename.c_str()) == 0;
}

bool TVPRenameFile(const std::string &from, const std::string &to) {
    return rename(from.c_str(), to.c_str()) == 0;
}

bool TVPCopyFile(const std::string &from, const std::string &to) {
    try {
        const std::filesystem::path fromPath(from);
        const std::filesystem::path toPath(to);

        if(std::filesystem::is_directory(fromPath)) {
            std::filesystem::create_directories(toPath);
            std::filesystem::copy(
                fromPath, toPath,
                std::filesystem::copy_options::recursive |
                    std::filesystem::copy_options::overwrite_existing);
            return true;
        }

        const auto parent = toPath.parent_path();
        if(!parent.empty()) {
            std::filesystem::create_directories(parent);
        }

        return std::filesystem::copy_file(
            fromPath, toPath, std::filesystem::copy_options::overwrite_existing);
    } catch(...) {
        return false;
    }
}

std::vector<std::string> TVPGetDriverPath() {
    return { "/" };
}

std::vector<std::string> TVPGetAppStoragePath() {
    return { TVPGetDefaultFileDirImpl() };
}

bool TVP_utime(const char *name, time_t modtime) {
    timeval mt[2];
    mt[0].tv_sec = modtime;
    mt[0].tv_usec = 0;
    mt[1].tv_sec = modtime;
    mt[1].tv_usec = 0;
    return utimes(name, mt) == 0;
}
