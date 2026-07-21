#include <atomic>
#include <cstdlib>
#include <thread>
#include <vector>
#include "../../Library/STD/@Native/TCP.cpp"
namespace {
void collect(void* context,std::int64_t value){static_cast<std::vector<std::int64_t>*>(context)->push_back(value);}
}
int main(){
    const std::uint8_t loopback[4]={127,0,0,1};
    SilexNative_STD_Network_TCP_native_listenResult listening{};
    silexNative_STD_Network_TCP_native_listen(4,loopback,4,0,0,8,&listening);
    if(listening.tag!=SilexNative_STD_Network_TCP_native_listenResultTag_success)return 2;
    auto* listener=listening.success_value;std::vector<std::int64_t> fields;SilexTcpOperation endpointResult{};
    silexNative_STD_Network_TCP_native_listener_endpoint(listener,collect,&fields,&endpointResult);
    if(!endpointResult.succeeded||fields.size()!=19||fields[1]<=0)return 3;
    std::atomic<int> clientResult{0};
    std::thread client([&]{SilexNative_STD_Network_TCP_native_connectResult connected{};silexNative_STD_Network_TCP_native_connect(4,loopback,4,fields[1],0,2000,2000,2000,&connected);if(connected.tag!=SilexNative_STD_Network_TCP_native_connectResultTag_success){clientResult=4;return;}auto*s=connected.success_value;std::vector<std::uint8_t> data(70000,42);std::size_t offset=0;while(offset<data.size()){SilexNative_STD_Network_TCP_native_writeResult w{};silexNative_STD_Network_TCP_native_write(s,data.data()+offset,data.size()-offset,&w);if(w.tag!=SilexNative_STD_Network_TCP_native_writeResultTag_success){clientResult=5;return;}offset+=w.success_value;}SilexNative_STD_Network_TCP_native_shutdownResult shut{};silexNative_STD_Network_TCP_native_shutdown(s,true,&shut);std::uint8_t reply[3]{};SilexNative_STD_Network_TCP_native_readResult read{};silexNative_STD_Network_TCP_native_read(s,reply,3,&read);if(read.tag!=SilexNative_STD_Network_TCP_native_readResultTag_success||read.success_value!=3||reply[0]!=1)clientResult=6;SilexNative_STD_Network_TCP_native_close_streamResult closed{};silexNative_STD_Network_TCP_native_close_stream(s,&closed);});
    SilexNative_STD_Network_TCP_native_acceptResult accepted{};silexNative_STD_Network_TCP_native_accept(listener,2000,2000,2000,&accepted);if(accepted.tag!=SilexNative_STD_Network_TCP_native_acceptResultTag_success)return 7;auto*stream=accepted.success_value;std::size_t total=0;std::uint8_t buffer[4096];while(true){SilexNative_STD_Network_TCP_native_readResult read{};silexNative_STD_Network_TCP_native_read(stream,buffer,sizeof(buffer),&read);if(read.tag!=SilexNative_STD_Network_TCP_native_readResultTag_success)return 8;if(read.success_value==0)break;total+=read.success_value;}if(total!=70000)return 9;const std::uint8_t reply[3]={1,2,3};SilexNative_STD_Network_TCP_native_writeResult written{};silexNative_STD_Network_TCP_native_write(stream,reply,3,&written);client.join();if(clientResult!=0)return clientResult;SilexNative_STD_Network_TCP_native_close_streamResult streamClosed{};silexNative_STD_Network_TCP_native_close_stream(stream,&streamClosed);SilexNative_STD_Network_TCP_native_acceptResult timed{};silexNative_STD_Network_TCP_native_accept(listener,0,-1,-1,&timed);if(timed.tag!=SilexNative_STD_Network_TCP_native_acceptResultTag_failure)return 10;SilexNative_STD_Network_TCP_native_close_listenerResult listenerClosed{};silexNative_STD_Network_TCP_native_close_listener(listener,&listenerClosed);return listenerClosed.tag==SilexNative_STD_Network_TCP_native_close_listenerResultTag_success?0:11;
}
