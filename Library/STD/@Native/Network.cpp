#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <system_error>
#include <vector>
#if defined(_WIN32)
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#endif

struct SilexNetworkResult { bool succeeded; std::int64_t kind; char* detail_bytes; std::int64_t detail_length; };
extern "C" std::int64_t silexSystemErrorKindFromPosix(int);
extern "C" std::int64_t silexSystemErrorKindFromWinsock(int);
namespace {
char* copy(const std::string&s){if(s.empty())return nullptr;auto*p=static_cast<char*>(std::malloc(s.size()));if(p)std::memcpy(p,s.data(),s.size());return p;}
void success(SilexNetworkResult*o){o->succeeded=true;o->kind=0;o->detail_bytes=nullptr;o->detail_length=0;}
void failure(SilexNetworkResult*o,std::int64_t k,const std::string&d){o->succeeded=false;o->kind=k;o->detail_bytes=copy(d);o->detail_length=d.size();}
void sockets(){
#if defined(_WIN32)
 static const bool ready=[](){WSADATA data{};return WSAStartup(MAKEWORD(2,2),&data)==0;}();(void)ready;
#endif
}
std::int64_t resolverKind(int code){
#if defined(_WIN32)
 return code==WSAHOST_NOT_FOUND||code==WSANO_DATA?0:silexSystemErrorKindFromWinsock(code);
#else
 if(code==EAI_NONAME)return 0;
#ifdef EAI_NODATA
 if(code==EAI_NODATA)return 0;
#endif
 if(code==EAI_SYSTEM)return silexSystemErrorKindFromPosix(errno);return 30;
#endif
}
std::string resolverDetail(int code){return gai_strerror(code);}
void visitAddress(void(*visitor)(void*,std::int64_t),void*ctx,int family,std::uint16_t port,std::uint32_t scope,const std::uint8_t*bytes){visitor(ctx,family);visitor(ctx,port);visitor(ctx,scope);for(int i=0;i<16;++i)visitor(ctx,family==4&&i>=4?0:bytes[i]);}
bool strictIpv4(const std::string& text){std::size_t start=0;for(int part=0;part<4;++part){auto end=text.find('.',start);if((part<3&&end==std::string::npos)||(part==3&&end!=std::string::npos))return false;if(end==std::string::npos)end=text.size();if(end==start||(end-start>1&&text[start]=='0'))return false;int value=0;for(auto i=start;i<end;++i){if(text[i]<'0'||text[i]>'9')return false;value=value*10+(text[i]-'0');if(value>255)return false;}start=end+1;}return true;}
}
extern "C" void silexNative_STD_Network_native_parse_ip(const char*b,std::int64_t l,void(*visitor)(void*,std::int64_t),void*ctx,SilexNetworkResult*o){sockets();std::string text(b,l);std::uint8_t bytes[16]{};int family=0;if(strictIpv4(text)&&inet_pton(AF_INET,text.c_str(),bytes)==1)family=4;else if(inet_pton(AF_INET6,text.c_str(),bytes)==1)family=6;else{failure(o,3,"invalid IP address");return;}visitor(ctx,family);for(int i=0;i<(family==4?4:16);++i)visitor(ctx,bytes[i]);success(o);}
extern "C" void silexNative_STD_Network_native_format_ip(std::int64_t family,const std::uint8_t*bytes,std::int64_t,char**out,std::int64_t*length){char text[INET6_ADDRSTRLEN]{};inet_ntop(family==4?AF_INET:AF_INET6,bytes,text,sizeof(text));std::string value(text);*out=copy(value);*length=value.size();}
extern "C" void silexNative_STD_Network_native_format_endpoint(std::int64_t family,std::int64_t port,std::int64_t scope,const std::uint8_t*bytes,std::int64_t count,char**out,std::int64_t*length){char*ip=nullptr;std::int64_t ipLength=0;silexNative_STD_Network_native_format_ip(family,bytes,count,&ip,&ipLength);std::string value;if(family==4)value=std::string(ip,ipLength)+":"+std::to_string(port);else value="["+std::string(ip,ipLength)+(scope?"%"+std::to_string(scope):"")+"]:"+std::to_string(port);std::free(ip);*out=copy(value);*length=value.size();}
extern "C" void silexNative_STD_Network_native_resolve(const char*b,std::int64_t l,std::int64_t port,std::int64_t family,std::int64_t transport,void(*visitor)(void*,std::int64_t),void*ctx,SilexNetworkResult*o){sockets();std::string host(b,l);if(host.empty()||host.find('\0')!=std::string::npos){failure(o,3,"invalid host");return;}for(unsigned char c:host)if(c>127){failure(o,3,"host must be ASCII");return;}addrinfo hints{};hints.ai_family=family==4?AF_INET:family==6?AF_INET6:AF_UNSPEC;hints.ai_socktype=transport==1?SOCK_STREAM:SOCK_DGRAM;hints.ai_protocol=transport==1?IPPROTO_TCP:IPPROTO_UDP;addrinfo*list=nullptr;auto service=std::to_string(port);int code=getaddrinfo(host.c_str(),service.c_str(),&hints,&list);if(code){failure(o,resolverKind(code),resolverDetail(code));return;}std::vector<std::vector<std::uint8_t>> seen;for(auto*entry=list;entry;entry=entry->ai_next){std::uint8_t bytes[16]{};int f=0;std::uint16_t resolvedPort=0;std::uint32_t scope=0;if(entry->ai_family==AF_INET){auto*a=reinterpret_cast<sockaddr_in*>(entry->ai_addr);f=4;resolvedPort=ntohs(a->sin_port);std::memcpy(bytes,&a->sin_addr,4);}else if(entry->ai_family==AF_INET6){auto*a=reinterpret_cast<sockaddr_in6*>(entry->ai_addr);f=6;resolvedPort=ntohs(a->sin6_port);scope=a->sin6_scope_id;std::memcpy(bytes,&a->sin6_addr,16);}else continue;std::vector<std::uint8_t>key(bytes,bytes+16);key.push_back(f);key.push_back(resolvedPort>>8);key.push_back(resolvedPort&255);for(int x=0;x<4;++x)key.push_back((scope>>(x*8))&255);if(std::find(seen.begin(),seen.end(),key)!=seen.end())continue;seen.push_back(key);visitAddress(visitor,ctx,f,resolvedPort,scope,bytes);}freeaddrinfo(list);if(seen.empty()){failure(o,0,"no address found");return;}success(o);}
