#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <system_error>
#if defined(_WIN32)
#include <winsock2.h>
#include <ws2tcpip.h>
using SocketHandle=SOCKET;constexpr SocketHandle invalidSocket=INVALID_SOCKET;
#else
#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>
using SocketHandle=int;constexpr SocketHandle invalidSocket=-1;
#endif
struct SilexNative_STD_Network_TCP_Stream{SocketHandle socket;bool readClosed=false,writeClosed=false;int readTimeout=-1,writeTimeout=-1;};
struct SilexNative_STD_Network_TCP_Listener{SocketHandle socket;};
struct SilexNative_STD_Network_TCP_NativeFailure{std::int64_t kind;char*detail_bytes;std::int64_t detail_length;};
struct SilexTcpOperation{bool succeeded;std::int64_t kind;char*detail_bytes;std::int64_t detail_length;};
#define R(N,S) enum SilexNative_STD_Network_TCP_##N##ResultTag{SilexNative_STD_Network_TCP_##N##ResultTag_success=0,SilexNative_STD_Network_TCP_##N##ResultTag_failure=1};struct SilexNative_STD_Network_TCP_##N##Result{SilexNative_STD_Network_TCP_##N##ResultTag tag;S SilexNative_STD_Network_TCP_NativeFailure failure_value;}
R(native_connect,SilexNative_STD_Network_TCP_Stream*success_value;);R(native_listen,SilexNative_STD_Network_TCP_Listener*success_value;);R(native_accept,SilexNative_STD_Network_TCP_Stream*success_value;);R(native_read,std::int64_t success_value;);R(native_write,std::int64_t success_value;);R(native_shutdown,);R(native_close_stream,);R(native_close_listener,);
#undef R
extern "C" std::int64_t silexSystemErrorKindFromPosix(int);extern "C" std::int64_t silexSystemErrorKindFromWinsock(int);
namespace{
char*copy(const std::string&s){if(s.empty())return nullptr;auto*p=static_cast<char*>(std::malloc(s.size()));if(p)std::memcpy(p,s.data(),s.size());return p;}
void init(){
#if defined(_WIN32)
static bool x=[](){WSADATA d{};return WSAStartup(MAKEWORD(2,2),&d)==0;}();(void)x;
#endif
}
int last(){
#if defined(_WIN32)
return WSAGetLastError();
#else
return errno;
#endif
}
std::int64_t kind(int e){
#if defined(_WIN32)
return silexSystemErrorKindFromWinsock(e);
#else
return silexSystemErrorKindFromPosix(e);
#endif
}
std::string detail(int e){return std::system_category().message(e);}
void closeSocket(SocketHandle s){
#if defined(_WIN32)
closesocket(s);
#else
close(s);
#endif
}
template<class O,class T>void fail(O*o,T tag,int e){o->tag=tag;o->failure_value.kind=kind(e);auto d=detail(e);o->failure_value.detail_bytes=copy(d);o->failure_value.detail_length=d.size();}
template<class O,class T>void failTimeout(O*o,T tag,int e){o->tag=tag;o->failure_value.kind=18;auto d=detail(e);o->failure_value.detail_bytes=copy(d);o->failure_value.detail_length=d.size();}
bool isTimeout(int e){
#if defined(_WIN32)
return e==WSAETIMEDOUT||e==WSAEWOULDBLOCK;
#else
return e==ETIMEDOUT||e==EAGAIN||e==EWOULDBLOCK;
#endif
}
bool address(int family,const std::uint8_t*b,int port,int scope,sockaddr_storage&storage,socklen_t&length){std::memset(&storage,0,sizeof(storage));if(family==4){auto*a=reinterpret_cast<sockaddr_in*>(&storage);a->sin_family=AF_INET;a->sin_port=htons(port);std::memcpy(&a->sin_addr,b,4);length=sizeof(*a);}else{auto*a=reinterpret_cast<sockaddr_in6*>(&storage);a->sin6_family=AF_INET6;a->sin6_port=htons(port);a->sin6_scope_id=scope;std::memcpy(&a->sin6_addr,b,16);length=sizeof(*a);}return true;}
void timeouts(SocketHandle s,int read,int write){
#if defined(_WIN32)
if(read>=0){DWORD v=read;setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,reinterpret_cast<char*>(&v),sizeof(v));}if(write>=0){DWORD v=write;setsockopt(s,SOL_SOCKET,SO_SNDTIMEO,reinterpret_cast<char*>(&v),sizeof(v));}
#else
if(read>=0){timeval v{read/1000,(read%1000)*1000};setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,&v,sizeof(v));}if(write>=0){timeval v{write/1000,(write%1000)*1000};setsockopt(s,SOL_SOCKET,SO_SNDTIMEO,&v,sizeof(v));}
#endif
}
int waitReady(SocketHandle s,int timeout,bool write){if(timeout<0)return 1;fd_set set;FD_ZERO(&set);FD_SET(s,&set);timeval v{timeout/1000,(timeout%1000)*1000};return select(static_cast<int>(s+1),write?nullptr:&set,write?&set:nullptr,nullptr,&v);}
void setTimedOut(){
#if defined(_WIN32)
WSASetLastError(WSAETIMEDOUT);
#else
errno=ETIMEDOUT;
#endif
}
void endpoint(SocketHandle s,bool peer,void(*visit)(void*,std::int64_t),void*ctx,SilexTcpOperation*out){sockaddr_storage a{};socklen_t n=sizeof(a);int r=peer?getpeername(s,reinterpret_cast<sockaddr*>(&a),&n):getsockname(s,reinterpret_cast<sockaddr*>(&a),&n);if(r){int e=last();out->succeeded=false;out->kind=kind(e);auto d=detail(e);out->detail_bytes=copy(d);out->detail_length=d.size();return;}std::uint8_t b[16]{};int f,port;std::uint32_t scope=0;if(a.ss_family==AF_INET){auto*x=reinterpret_cast<sockaddr_in*>(&a);f=4;port=ntohs(x->sin_port);std::memcpy(b,&x->sin_addr,4);}else{auto*x=reinterpret_cast<sockaddr_in6*>(&a);f=6;port=ntohs(x->sin6_port);scope=x->sin6_scope_id;std::memcpy(b,&x->sin6_addr,16);}visit(ctx,f);visit(ctx,port);visit(ctx,scope);for(int i=0;i<16;++i)visit(ctx,b[i]);out->succeeded=true;out->kind=0;out->detail_bytes=nullptr;out->detail_length=0;}
}
extern "C" void silexNative_STD_Network_TCP_discard_stream(SilexNative_STD_Network_TCP_Stream*s){if(s){closeSocket(s->socket);delete s;}}
extern "C" void silexNative_STD_Network_TCP_discard_listener(SilexNative_STD_Network_TCP_Listener*s){if(s){closeSocket(s->socket);delete s;}}
extern "C" void silexNative_STD_Network_TCP_native_connect(std::int64_t family,const std::uint8_t*b,std::int64_t,std::int64_t port,std::int64_t scope,std::int64_t timeout,std::int64_t read,std::int64_t write,SilexNative_STD_Network_TCP_native_connectResult*o){init();auto s=socket(family==4?AF_INET:AF_INET6,SOCK_STREAM,IPPROTO_TCP);if(s==invalidSocket){fail(o,SilexNative_STD_Network_TCP_native_connectResultTag_failure,last());return;}sockaddr_storage a;socklen_t n;address(family,b,port,scope,a,n);if(timeout>=0){
#if defined(_WIN32)
u_long mode=1;ioctlsocket(s,FIONBIO,&mode);
#else
fcntl(s,F_SETFL,fcntl(s,F_GETFL,0)|O_NONBLOCK);
#endif
}int r=::connect(s,reinterpret_cast<sockaddr*>(&a),n);if(r&&timeout>=0){fd_set set;FD_ZERO(&set);FD_SET(s,&set);timeval v{static_cast<decltype(timeval{}.tv_sec)>(timeout/1000),static_cast<decltype(timeval{}.tv_usec)>((timeout%1000)*1000)};r=select(static_cast<int>(s+1),nullptr,&set,nullptr,&v);if(r>0){int e=0;socklen_t z=sizeof(e);getsockopt(s,SOL_SOCKET,SO_ERROR,reinterpret_cast<char*>(&e),&z);if(e){
#if defined(_WIN32)
WSASetLastError(e);
#else
errno=e;
#endif
r=-1;}else r=0;}else{
#if defined(_WIN32)
WSASetLastError(WSAETIMEDOUT);
#else
errno=ETIMEDOUT;
#endif
r=-1;}}
if(timeout>=0){
#if defined(_WIN32)
u_long mode=0;ioctlsocket(s,FIONBIO,&mode);
#else
fcntl(s,F_SETFL,fcntl(s,F_GETFL,0)&~O_NONBLOCK);
#endif
}if(r){int e=last();closeSocket(s);fail(o,SilexNative_STD_Network_TCP_native_connectResultTag_failure,e);return;}timeouts(s,read,write);o->tag=SilexNative_STD_Network_TCP_native_connectResultTag_success;o->success_value=new SilexNative_STD_Network_TCP_Stream{s,false,false,static_cast<int>(read),static_cast<int>(write)};}
extern "C" void silexNative_STD_Network_TCP_native_listen(std::int64_t family,const std::uint8_t*b,std::int64_t,std::int64_t port,std::int64_t scope,std::int64_t backlog,SilexNative_STD_Network_TCP_native_listenResult*o){init();auto s=socket(family==4?AF_INET:AF_INET6,SOCK_STREAM,IPPROTO_TCP);if(s==invalidSocket){fail(o,SilexNative_STD_Network_TCP_native_listenResultTag_failure,last());return;}int one=1;setsockopt(s,SOL_SOCKET,SO_REUSEADDR,reinterpret_cast<char*>(&one),sizeof(one));if(family==6)setsockopt(s,IPPROTO_IPV6,IPV6_V6ONLY,reinterpret_cast<char*>(&one),sizeof(one));sockaddr_storage a;socklen_t n;address(family,b,port,scope,a,n);if(bind(s,reinterpret_cast<sockaddr*>(&a),n)||::listen(s,backlog)){int e=last();closeSocket(s);fail(o,SilexNative_STD_Network_TCP_native_listenResultTag_failure,e);return;}o->tag=SilexNative_STD_Network_TCP_native_listenResultTag_success;o->success_value=new SilexNative_STD_Network_TCP_Listener{s};}
extern "C" void silexNative_STD_Network_TCP_native_accept(SilexNative_STD_Network_TCP_Listener*l,std::int64_t timeout,std::int64_t read,std::int64_t write,SilexNative_STD_Network_TCP_native_acceptResult*o){int ready=waitReady(l->socket,timeout,false);if(ready<=0){if(ready==0)setTimedOut();fail(o,SilexNative_STD_Network_TCP_native_acceptResultTag_failure,last());return;}auto s=accept(l->socket,nullptr,nullptr);if(s==invalidSocket){fail(o,SilexNative_STD_Network_TCP_native_acceptResultTag_failure,last());return;}timeouts(s,read,write);o->tag=SilexNative_STD_Network_TCP_native_acceptResultTag_success;o->success_value=new SilexNative_STD_Network_TCP_Stream{s,false,false,static_cast<int>(read),static_cast<int>(write)};}
extern "C" void silexNative_STD_Network_TCP_native_read(SilexNative_STD_Network_TCP_Stream*s,std::uint8_t*b,std::int64_t n,SilexNative_STD_Network_TCP_native_readResult*o){if(s->readClosed){
#if defined(_WIN32)
WSASetLastError(WSAENOTCONN);
#else
errno=ENOTCONN;
#endif
fail(o,SilexNative_STD_Network_TCP_native_readResultTag_failure,last());return;}int ready=waitReady(s->socket,s->readTimeout,false);if(ready<=0){if(ready==0){setTimedOut();failTimeout(o,SilexNative_STD_Network_TCP_native_readResultTag_failure,last());}else fail(o,SilexNative_STD_Network_TCP_native_readResultTag_failure,last());return;}auto r=recv(s->socket,reinterpret_cast<char*>(b),static_cast<int>(std::min<std::int64_t>(n,INT_MAX)),0);if(r<0){int e=last();if(isTimeout(e))failTimeout(o,SilexNative_STD_Network_TCP_native_readResultTag_failure,e);else fail(o,SilexNative_STD_Network_TCP_native_readResultTag_failure,e);return;}o->tag=SilexNative_STD_Network_TCP_native_readResultTag_success;o->success_value=r;}
extern "C" void silexNative_STD_Network_TCP_native_write(SilexNative_STD_Network_TCP_Stream*s,const std::uint8_t*b,std::int64_t n,SilexNative_STD_Network_TCP_native_writeResult*o){if(s->writeClosed){
#if defined(_WIN32)
WSASetLastError(WSAENOTCONN);
#else
errno=ENOTCONN;
#endif
fail(o,SilexNative_STD_Network_TCP_native_writeResultTag_failure,last());return;}int ready=waitReady(s->socket,s->writeTimeout,true);if(ready<=0){if(ready==0){setTimedOut();failTimeout(o,SilexNative_STD_Network_TCP_native_writeResultTag_failure,last());}else fail(o,SilexNative_STD_Network_TCP_native_writeResultTag_failure,last());return;}int flags=0;
#if defined(MSG_NOSIGNAL)
flags=MSG_NOSIGNAL;
#endif
auto r=send(s->socket,reinterpret_cast<const char*>(b),static_cast<int>(std::min<std::int64_t>(n,INT_MAX)),flags);if(r<0){int e=last();if(isTimeout(e))failTimeout(o,SilexNative_STD_Network_TCP_native_writeResultTag_failure,e);else fail(o,SilexNative_STD_Network_TCP_native_writeResultTag_failure,e);return;}o->tag=SilexNative_STD_Network_TCP_native_writeResultTag_success;o->success_value=r;}
extern "C" void silexNative_STD_Network_TCP_native_shutdown(SilexNative_STD_Network_TCP_Stream*s,bool write,SilexNative_STD_Network_TCP_native_shutdownResult*o){bool&closed=write?s->writeClosed:s->readClosed;if(!closed&&shutdown(s->socket,write?
#if defined(_WIN32)
SD_SEND:SD_RECEIVE
#else
SHUT_WR:SHUT_RD
#endif
)){fail(o,SilexNative_STD_Network_TCP_native_shutdownResultTag_failure,last());return;}closed=true;o->tag=SilexNative_STD_Network_TCP_native_shutdownResultTag_success;}
extern "C" void silexNative_STD_Network_TCP_native_close_stream(SilexNative_STD_Network_TCP_Stream*s,SilexNative_STD_Network_TCP_native_close_streamResult*o){int r=
#if defined(_WIN32)
closesocket(s->socket);
#else
close(s->socket);
#endif
delete s;if(r){fail(o,SilexNative_STD_Network_TCP_native_close_streamResultTag_failure,last());return;}o->tag=SilexNative_STD_Network_TCP_native_close_streamResultTag_success;}
extern "C" void silexNative_STD_Network_TCP_native_close_listener(SilexNative_STD_Network_TCP_Listener*s,SilexNative_STD_Network_TCP_native_close_listenerResult*o){int r=
#if defined(_WIN32)
closesocket(s->socket);
#else
close(s->socket);
#endif
delete s;if(r){fail(o,SilexNative_STD_Network_TCP_native_close_listenerResultTag_failure,last());return;}o->tag=SilexNative_STD_Network_TCP_native_close_listenerResultTag_success;}
extern "C" void silexNative_STD_Network_TCP_native_stream_endpoint(SilexNative_STD_Network_TCP_Stream*s,bool peer,void(*v)(void*,std::int64_t),void*c,SilexTcpOperation*o){endpoint(s->socket,peer,v,c,o);}
extern "C" void silexNative_STD_Network_TCP_native_listener_endpoint(SilexNative_STD_Network_TCP_Listener*s,void(*v)(void*,std::int64_t),void*c,SilexTcpOperation*o){endpoint(s->socket,false,v,c,o);}
extern "C" void silexNative_STD_Network_TCP_native_subject(const char*host,std::int64_t length,std::int64_t port,char**out,std::int64_t*outLength){std::string value(host,length);value+=":"+std::to_string(port);*out=copy(value);*outLength=value.size();}
