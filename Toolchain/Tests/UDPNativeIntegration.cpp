#include <cstdint>
#include <vector>

#include "../../Library/STD/@Native/UDP.cpp"

namespace {

void collect(void* context, std::int64_t value) {
    static_cast<std::vector<std::int64_t>*>(context)->push_back(value);
}

bool send(SilexNative_STD_Network_UDP_Socket* socket, const std::uint8_t* bytes,
          std::int64_t count, int family, const std::uint8_t* address, int port,
          std::int64_t* failureKind = nullptr) {
    SilexNative_STD_Network_UDP_native_send_toResult result{};
    silexNative_STD_Network_UDP_native_send_to(socket, bytes, count, family, address,
                                               family == 4 ? 4 : 16, port, 0, &result);
    if (result.tag == SilexNative_STD_Network_UDP_native_send_toResultTag_success) {
        return true;
    }
    if (failureKind != nullptr) *failureKind = result.failure_value.kind;
    return false;
}

}  // namespace

int main() {
    const std::uint8_t loopback[4] = {127, 0, 0, 1};
    SilexNative_STD_Network_UDP_native_bindResult bound{};
    silexNative_STD_Network_UDP_native_bind(4, loopback, 4, 0, 0, 100, 100, &bound);
    if (bound.tag != SilexNative_STD_Network_UDP_native_bindResultTag_success) return 2;
    auto* receiver = bound.success_value;

    std::vector<std::int64_t> endpointFields;
    SilexNative_STD_Network_UDP_NativeOperation endpointResult{};
    silexNative_STD_Network_UDP_native_local_endpoint(receiver, collect, &endpointFields,
                                                      &endpointResult);
    if (!endpointResult.succeeded || endpointFields.size() != 19 || endpointFields[1] <= 0) {
        return 3;
    }
    const int port = static_cast<int>(endpointFields[1]);

    SilexNative_STD_Network_UDP_native_openResult opened{};
    silexNative_STD_Network_UDP_native_open(4, 100, 100, &opened);
    if (opened.tag != SilexNative_STD_Network_UDP_native_openResultTag_success) return 4;
    auto* sender = opened.success_value;

    const std::uint8_t empty = 0;
    if (!send(sender, &empty, 0, 4, loopback, port)) return 5;
    std::uint8_t noBuffer = 0;
    std::vector<std::int64_t> senderFields;
    SilexNative_STD_Network_UDP_NativeReceiveOperation emptyReceive{};
    silexNative_STD_Network_UDP_native_receive_from(receiver, &noBuffer, 0, collect,
                                                    &senderFields, &emptyReceive);
    if (!emptyReceive.succeeded || emptyReceive.count != 0 || emptyReceive.truncated ||
        senderFields.size() != 19 || senderFields[1] <= 0) {
        return 6;
    }

    const std::uint8_t large[5] = {1, 2, 3, 4, 5};
    if (!send(sender, large, 5, 4, loopback, port)) return 7;
    std::uint8_t prefix[2]{};
    senderFields.clear();
    SilexNative_STD_Network_UDP_NativeReceiveOperation truncated{};
    silexNative_STD_Network_UDP_native_receive_from(receiver, prefix, 2, collect,
                                                    &senderFields, &truncated);
    if (!truncated.succeeded || truncated.count != 2 || !truncated.truncated ||
        prefix[0] != 1 || prefix[1] != 2) {
        return 8;
    }

    const std::uint8_t following = 9;
    if (!send(sender, &following, 1, 4, loopback, port)) return 9;
    std::uint8_t received = 0;
    senderFields.clear();
    SilexNative_STD_Network_UDP_NativeReceiveOperation next{};
    silexNative_STD_Network_UDP_native_receive_from(receiver, &received, 1, collect,
                                                    &senderFields, &next);
    if (!next.succeeded || next.count != 1 || next.truncated || received != 9) return 10;

    SilexNative_STD_Network_UDP_NativeReceiveOperation timed{};
    receiver->readTimeout = 0;
    senderFields.clear();
    silexNative_STD_Network_UDP_native_receive_from(receiver, &received, 1, collect,
                                                    &senderFields, &timed);
    if (timed.succeeded || timed.kind != 18) return 11;

    std::int64_t incompatibleKind = 0;
    const std::uint8_t ipv6[16]{};
    if (send(sender, &following, 1, 6, ipv6, port, &incompatibleKind) ||
        incompatibleKind != 3) {
        return 12;
    }

    std::vector<std::uint8_t> oversized(70000, 42);
    std::int64_t oversizedKind = 0;
    if (send(sender, oversized.data(), oversized.size(), 4, loopback, port,
             &oversizedKind) ||
        oversizedKind != 20) {
        return 13;
    }

    SilexNative_STD_Network_UDP_native_bindResult occupied{};
    silexNative_STD_Network_UDP_native_bind(4, loopback, 4, port, 0, 100, 100, &occupied);
    if (occupied.tag != SilexNative_STD_Network_UDP_native_bindResultTag_failure ||
        occupied.failure_value.kind != 21) {
        return 14;
    }

    SilexNative_STD_Network_UDP_native_closeResult senderClosed{};
    silexNative_STD_Network_UDP_native_close(sender, &senderClosed);
    SilexNative_STD_Network_UDP_native_closeResult receiverClosed{};
    silexNative_STD_Network_UDP_native_close(receiver, &receiverClosed);
    return senderClosed.tag == SilexNative_STD_Network_UDP_native_closeResultTag_success &&
                   receiverClosed.tag == SilexNative_STD_Network_UDP_native_closeResultTag_success
               ? 0
               : 15;
}
