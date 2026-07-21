#include <algorithm>
#include <cerrno>
#include <climits>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <system_error>
#include <vector>

#if defined(_WIN32)
#include <winsock2.h>
#include <ws2tcpip.h>
using SocketHandle = SOCKET;
using SocketLength = int;
constexpr SocketHandle invalidSocket = INVALID_SOCKET;
#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>
using SocketHandle = int;
using SocketLength = socklen_t;
constexpr SocketHandle invalidSocket = -1;
#endif

struct SilexNative_STD_Network_UDP_Socket {
    SocketHandle socket;
    int family;
    int readTimeout;
    int writeTimeout;
};
struct SilexNative_STD_Network_UDP_NativeFailure {
    std::int64_t kind;
    char* detail_bytes;
    std::int64_t detail_length;
};
struct SilexNative_STD_Network_UDP_NativeOperation {
    bool succeeded;
    std::int64_t kind;
    char* detail_bytes;
    std::int64_t detail_length;
};
struct SilexNative_STD_Network_UDP_NativeReceiveOperation {
    bool succeeded;
    std::int64_t kind;
    char* detail_bytes;
    std::int64_t detail_length;
    std::int64_t count;
    bool truncated;
};

#define SILEX_UDP_RESULT(NAME, SUCCESS_FIELD)                                      \
    enum SilexNative_STD_Network_UDP_##NAME##ResultTag {                           \
        SilexNative_STD_Network_UDP_##NAME##ResultTag_success = 0,                 \
        SilexNative_STD_Network_UDP_##NAME##ResultTag_failure = 1,                 \
    };                                                                             \
    struct SilexNative_STD_Network_UDP_##NAME##Result {                            \
        SilexNative_STD_Network_UDP_##NAME##ResultTag tag;                         \
        SUCCESS_FIELD SilexNative_STD_Network_UDP_NativeFailure failure_value;     \
    }
SILEX_UDP_RESULT(native_bind, SilexNative_STD_Network_UDP_Socket* success_value;);
SILEX_UDP_RESULT(native_open, SilexNative_STD_Network_UDP_Socket* success_value;);
SILEX_UDP_RESULT(native_send_to, );
SILEX_UDP_RESULT(native_close, );
#undef SILEX_UDP_RESULT

extern "C" std::int64_t silexSystemErrorKindFromPosix(int);
extern "C" std::int64_t silexSystemErrorKindFromWinsock(int);

namespace {

constexpr std::int64_t invalidInput = 3;
constexpr std::int64_t timedOut = 18;
constexpr std::int64_t messageTooLarge = 20;

char* copy(const std::string& value) {
    if (value.empty()) return nullptr;
    auto* result = static_cast<char*>(std::malloc(value.size()));
    if (result != nullptr) std::memcpy(result, value.data(), value.size());
    return result;
}

void initializeSockets() {
#if defined(_WIN32)
    static const bool initialized = [] {
        WSADATA data{};
        return WSAStartup(MAKEWORD(2, 2), &data) == 0;
    }();
    (void)initialized;
#endif
}

int lastError() {
#if defined(_WIN32)
    return WSAGetLastError();
#else
    return errno;
#endif
}

std::int64_t errorKind(int error) {
#if defined(_WIN32)
    return silexSystemErrorKindFromWinsock(error);
#else
    return silexSystemErrorKindFromPosix(error);
#endif
}

std::string errorDetail(int error) { return std::system_category().message(error); }

void closeSocket(SocketHandle socket) {
#if defined(_WIN32)
    closesocket(socket);
#else
    close(socket);
#endif
}

template <typename Operation, typename Tag>
void fail(Operation* operation, Tag tag, int error) {
    operation->tag = tag;
    operation->failure_value.kind = errorKind(error);
    const auto detail = errorDetail(error);
    operation->failure_value.detail_bytes = copy(detail);
    operation->failure_value.detail_length = static_cast<std::int64_t>(detail.size());
}

template <typename Operation, typename Tag>
void failKind(Operation* operation, Tag tag, std::int64_t kind, const std::string& detail) {
    operation->tag = tag;
    operation->failure_value.kind = kind;
    operation->failure_value.detail_bytes = copy(detail);
    operation->failure_value.detail_length = static_cast<std::int64_t>(detail.size());
}

template <typename Operation>
void operationFailure(Operation* operation, int error) {
    operation->succeeded = false;
    operation->kind = errorKind(error);
    const auto detail = errorDetail(error);
    operation->detail_bytes = copy(detail);
    operation->detail_length = static_cast<std::int64_t>(detail.size());
}

template <typename Operation>
void timeoutFailure(Operation* operation) {
    operation->succeeded = false;
    operation->kind = timedOut;
    const std::string detail = "operation timed out";
    operation->detail_bytes = copy(detail);
    operation->detail_length = static_cast<std::int64_t>(detail.size());
}

bool isTimeoutError(int error) {
#if defined(_WIN32)
    return error == WSAETIMEDOUT || error == WSAEWOULDBLOCK;
#else
    return error == ETIMEDOUT || error == EAGAIN || error == EWOULDBLOCK;
#endif
}

bool makeAddress(int family, const std::uint8_t* bytes, int port, int scope,
                 sockaddr_storage& storage, SocketLength& length) {
    std::memset(&storage, 0, sizeof(storage));
    if (family == 4) {
        auto* address = reinterpret_cast<sockaddr_in*>(&storage);
        address->sin_family = AF_INET;
        address->sin_port = htons(static_cast<std::uint16_t>(port));
        std::memcpy(&address->sin_addr, bytes, 4);
        length = sizeof(*address);
        return true;
    }
    if (family == 6) {
        auto* address = reinterpret_cast<sockaddr_in6*>(&storage);
        address->sin6_family = AF_INET6;
        address->sin6_port = htons(static_cast<std::uint16_t>(port));
        address->sin6_scope_id = static_cast<std::uint32_t>(scope);
        std::memcpy(&address->sin6_addr, bytes, 16);
        length = sizeof(*address);
        return true;
    }
    return false;
}

void configureTimeouts(SocketHandle socket, int readTimeout, int writeTimeout) {
#if defined(_WIN32)
    if (readTimeout > 0) {
        DWORD value = static_cast<DWORD>(readTimeout);
        setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<char*>(&value), sizeof(value));
    }
    if (writeTimeout > 0) {
        DWORD value = static_cast<DWORD>(writeTimeout);
        setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, reinterpret_cast<char*>(&value), sizeof(value));
    }
#else
    if (readTimeout > 0) {
        timeval value{readTimeout / 1000, (readTimeout % 1000) * 1000};
        setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &value, sizeof(value));
    }
    if (writeTimeout > 0) {
        timeval value{writeTimeout / 1000, (writeTimeout % 1000) * 1000};
        setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &value, sizeof(value));
    }
#endif
}

int waitFor(SocketHandle socket, int timeout, bool write) {
    if (timeout < 0) return 1;
    fd_set set;
    FD_ZERO(&set);
    FD_SET(socket, &set);
    timeval value{static_cast<decltype(timeval{}.tv_sec)>(timeout / 1000),
                  static_cast<decltype(timeval{}.tv_usec)>((timeout % 1000) * 1000)};
    return select(static_cast<int>(socket + 1), write ? nullptr : &set,
                  write ? &set : nullptr, nullptr, &value);
}

int datagramExceeds(SocketHandle socket, std::int64_t capacity) {
    const std::size_t probeSize = static_cast<std::size_t>(
        std::min<std::int64_t>(capacity + 1, 65536));
    std::vector<std::uint8_t> probe(probeSize);
    sockaddr_storage sender{};
    SocketLength length = sizeof(sender);
    const auto received = recvfrom(socket, reinterpret_cast<char*>(probe.data()),
                                   static_cast<int>(probe.size()), MSG_PEEK,
                                   reinterpret_cast<sockaddr*>(&sender), &length);
    if (received < 0) {
#if defined(_WIN32)
        if (lastError() == WSAEMSGSIZE) return 1;
#endif
        return -1;
    }
    return received > capacity ? 1 : 0;
}

void visitEndpoint(const sockaddr_storage& storage, void (*visitor)(void*, std::int64_t),
                   void* context) {
    std::uint8_t bytes[16]{};
    int family = 0;
    int port = 0;
    std::uint32_t scope = 0;
    if (storage.ss_family == AF_INET) {
        const auto* address = reinterpret_cast<const sockaddr_in*>(&storage);
        family = 4;
        port = ntohs(address->sin_port);
        std::memcpy(bytes, &address->sin_addr, 4);
    } else {
        const auto* address = reinterpret_cast<const sockaddr_in6*>(&storage);
        family = 6;
        port = ntohs(address->sin6_port);
        scope = address->sin6_scope_id;
        std::memcpy(bytes, &address->sin6_addr, 16);
    }
    visitor(context, family);
    visitor(context, port);
    visitor(context, scope);
    for (const auto byte : bytes) visitor(context, byte);
}

SilexNative_STD_Network_UDP_Socket* createSocket(int family, int readTimeout,
                                                  int writeTimeout, int& error) {
    initializeSockets();
    const auto socket = ::socket(family == 4 ? AF_INET : AF_INET6, SOCK_DGRAM, IPPROTO_UDP);
    if (socket == invalidSocket) {
        error = lastError();
        return nullptr;
    }
    if (family == 6) {
        int one = 1;
        setsockopt(socket, IPPROTO_IPV6, IPV6_V6ONLY, reinterpret_cast<char*>(&one), sizeof(one));
    }
    configureTimeouts(socket, readTimeout, writeTimeout);
    return new SilexNative_STD_Network_UDP_Socket{socket, family, readTimeout, writeTimeout};
}

}  // namespace

extern "C" void silexNative_STD_Network_UDP_discard_socket(
    SilexNative_STD_Network_UDP_Socket* socket) {
    if (socket == nullptr) return;
    closeSocket(socket->socket);
    delete socket;
}

extern "C" void silexNative_STD_Network_UDP_native_bind(
    std::int64_t family, const std::uint8_t* bytes, std::int64_t, std::int64_t port,
    std::int64_t scope, std::int64_t readTimeout, std::int64_t writeTimeout,
    SilexNative_STD_Network_UDP_native_bindResult* result) {
    int error = 0;
    auto* socket = createSocket(static_cast<int>(family), static_cast<int>(readTimeout),
                                static_cast<int>(writeTimeout), error);
    if (socket == nullptr) {
        fail(result, SilexNative_STD_Network_UDP_native_bindResultTag_failure, error);
        return;
    }
    sockaddr_storage address{};
    SocketLength length = 0;
    makeAddress(static_cast<int>(family), bytes, static_cast<int>(port),
                static_cast<int>(scope), address, length);
    if (::bind(socket->socket, reinterpret_cast<sockaddr*>(&address), length) != 0) {
        error = lastError();
        closeSocket(socket->socket);
        delete socket;
        fail(result, SilexNative_STD_Network_UDP_native_bindResultTag_failure, error);
        return;
    }
    result->tag = SilexNative_STD_Network_UDP_native_bindResultTag_success;
    result->success_value = socket;
}

extern "C" void silexNative_STD_Network_UDP_native_open(
    std::int64_t family, std::int64_t readTimeout, std::int64_t writeTimeout,
    SilexNative_STD_Network_UDP_native_openResult* result) {
    int error = 0;
    auto* socket = createSocket(static_cast<int>(family), static_cast<int>(readTimeout),
                                static_cast<int>(writeTimeout), error);
    if (socket == nullptr) {
        fail(result, SilexNative_STD_Network_UDP_native_openResultTag_failure, error);
        return;
    }
    result->tag = SilexNative_STD_Network_UDP_native_openResultTag_success;
    result->success_value = socket;
}

extern "C" void silexNative_STD_Network_UDP_native_send_to(
    SilexNative_STD_Network_UDP_Socket* socket, const std::uint8_t* bytes,
    std::int64_t count, std::int64_t family, const std::uint8_t* addressBytes,
    std::int64_t, std::int64_t port, std::int64_t scope,
    SilexNative_STD_Network_UDP_native_send_toResult* result) {
    if (socket->family != family) {
        failKind(result, SilexNative_STD_Network_UDP_native_send_toResultTag_failure,
                 invalidInput, "endpoint family does not match socket family");
        return;
    }
    if (count > INT_MAX) {
        failKind(result, SilexNative_STD_Network_UDP_native_send_toResultTag_failure,
                 messageTooLarge, "datagram is too large");
        return;
    }
    const int ready = waitFor(socket->socket, socket->writeTimeout, true);
    if (ready == 0) {
        failKind(result, SilexNative_STD_Network_UDP_native_send_toResultTag_failure,
                 timedOut, "operation timed out");
        return;
    }
    if (ready < 0) {
        fail(result, SilexNative_STD_Network_UDP_native_send_toResultTag_failure, lastError());
        return;
    }
    sockaddr_storage address{};
    SocketLength length = 0;
    makeAddress(static_cast<int>(family), addressBytes, static_cast<int>(port),
                static_cast<int>(scope), address, length);
    const auto sent = sendto(socket->socket, reinterpret_cast<const char*>(bytes),
                             static_cast<int>(count), 0,
                             reinterpret_cast<sockaddr*>(&address), length);
    if (sent < 0) {
        const int error = lastError();
        if (isTimeoutError(error)) {
            failKind(result, SilexNative_STD_Network_UDP_native_send_toResultTag_failure,
                     timedOut, errorDetail(error));
        } else {
            fail(result, SilexNative_STD_Network_UDP_native_send_toResultTag_failure, error);
        }
        return;
    }
    if (sent != count) {
        failKind(result, SilexNative_STD_Network_UDP_native_send_toResultTag_failure,
                 messageTooLarge, "partial datagram emission");
        return;
    }
    result->tag = SilexNative_STD_Network_UDP_native_send_toResultTag_success;
}

extern "C" void silexNative_STD_Network_UDP_native_receive_from(
    SilexNative_STD_Network_UDP_Socket* socket, std::uint8_t* buffer,
    std::int64_t capacity, void (*visitor)(void*, std::int64_t), void* context,
    SilexNative_STD_Network_UDP_NativeReceiveOperation* result) {
    const int ready = waitFor(socket->socket, socket->readTimeout, false);
    if (ready == 0) {
        timeoutFailure(result);
        return;
    }
    if (ready < 0) {
        operationFailure(result, lastError());
        return;
    }

    sockaddr_storage sender{};
    SocketLength senderLength = sizeof(sender);
    const int exceedsCapacity = datagramExceeds(socket->socket, capacity);
    std::int64_t received = 0;
    bool truncated = false;
#if defined(_WIN32)
    WSABUF data{static_cast<ULONG>(std::min<std::int64_t>(capacity, ULONG_MAX)),
                reinterpret_cast<char*>(buffer)};
    DWORD byteCount = 0;
    DWORD flags = 0;
    const int status = WSARecvFrom(socket->socket, &data, 1, &byteCount, &flags,
                                   reinterpret_cast<sockaddr*>(&sender), &senderLength,
                                   nullptr, nullptr);
    if (status == SOCKET_ERROR) {
        const int error = lastError();
        if (error == WSAEMSGSIZE) {
            truncated = true;
            received = byteCount;
        } else {
            if (isTimeoutError(error)) timeoutFailure(result);
            else operationFailure(result, error);
            return;
        }
    } else {
        received = byteCount;
        truncated = (flags & MSG_PARTIAL) != 0;
    }
#else
    iovec data{buffer, static_cast<std::size_t>(capacity)};
    msghdr message{};
    message.msg_name = &sender;
    message.msg_namelen = senderLength;
    message.msg_iov = &data;
    message.msg_iovlen = 1;
    const auto status = recvmsg(socket->socket, &message, 0);
    if (status < 0) {
        const int error = lastError();
        if (isTimeoutError(error)) timeoutFailure(result);
        else operationFailure(result, error);
        return;
    }
    senderLength = message.msg_namelen;
    received = status;
    truncated = (message.msg_flags & MSG_TRUNC) != 0;
#endif
    (void)senderLength;
    visitEndpoint(sender, visitor, context);
    result->succeeded = true;
    result->kind = 0;
    result->detail_bytes = nullptr;
    result->detail_length = 0;
    result->count = std::min(received, capacity);
    if (exceedsCapacity >= 0) {
        result->truncated = exceedsCapacity != 0;
    } else {
        result->truncated = truncated || received > capacity;
    }
}

extern "C" void silexNative_STD_Network_UDP_native_local_endpoint(
    SilexNative_STD_Network_UDP_Socket* socket, void (*visitor)(void*, std::int64_t),
    void* context, SilexNative_STD_Network_UDP_NativeOperation* result) {
    sockaddr_storage address{};
    SocketLength length = sizeof(address);
    if (getsockname(socket->socket, reinterpret_cast<sockaddr*>(&address), &length) != 0) {
        operationFailure(result, lastError());
        return;
    }
    visitEndpoint(address, visitor, context);
    result->succeeded = true;
    result->kind = 0;
    result->detail_bytes = nullptr;
    result->detail_length = 0;
}

extern "C" void silexNative_STD_Network_UDP_native_close(
    SilexNative_STD_Network_UDP_Socket* socket,
    SilexNative_STD_Network_UDP_native_closeResult* result) {
#if defined(_WIN32)
    const int status = closesocket(socket->socket);
#else
    const int status = close(socket->socket);
#endif
    const int error = status == 0 ? 0 : lastError();
    delete socket;
    if (status != 0) {
        fail(result, SilexNative_STD_Network_UDP_native_closeResultTag_failure, error);
        return;
    }
    result->tag = SilexNative_STD_Network_UDP_native_closeResultTag_success;
}
