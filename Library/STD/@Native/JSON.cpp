#include <charconv>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace {
struct Node {
    int kind = 1;
    bool boolean = false;
    std::string text;
    std::vector<std::shared_ptr<Node>> children;
    std::vector<std::string> names;
};
}

struct SilexNative_STD_JSON_NativeValue { std::shared_ptr<Node> node; };
struct SilexNative_STD_JSON_NativeBuildFailure { std::int64_t kind; char* text_bytes; std::int64_t text_length; };
struct SilexNative_STD_JSON_NativeParseFailure {
    std::int64_t kind, byte_offset, line, column;
    char* detail_bytes; std::int64_t detail_length;
};
#define JSON_RESULT(NAME, SUCCESS, FAILURE) enum SilexNative_STD_JSON_##NAME##ResultTag { SilexNative_STD_JSON_##NAME##ResultTag_success=0, SilexNative_STD_JSON_##NAME##ResultTag_failure=1 }; struct SilexNative_STD_JSON_##NAME##Result { SilexNative_STD_JSON_##NAME##ResultTag tag; SUCCESS FAILURE failure_value; }
JSON_RESULT(native_number_text, SilexNative_STD_JSON_NativeValue* success_value;, SilexNative_STD_JSON_NativeBuildFailure);
JSON_RESULT(native_number_float, SilexNative_STD_JSON_NativeValue* success_value;, SilexNative_STD_JSON_NativeBuildFailure);
JSON_RESULT(native_object_append, , SilexNative_STD_JSON_NativeBuildFailure);
JSON_RESULT(native_parse, SilexNative_STD_JSON_NativeValue* success_value;, SilexNative_STD_JSON_NativeParseFailure);
#undef JSON_RESULT

namespace {
char* copy(const std::string& value) { if (value.empty()) return nullptr; auto* p=static_cast<char*>(std::malloc(value.size())); if(p) std::memcpy(p,value.data(),value.size()); return p; }
SilexNative_STD_JSON_NativeValue* wrap(std::shared_ptr<Node> node) { return new SilexNative_STD_JSON_NativeValue{std::move(node)}; }
std::shared_ptr<Node> scalar(int kind, std::string text={}) { auto n=std::make_shared<Node>(); n->kind=kind; n->text=std::move(text); return n; }
bool numberValid(const std::string& s) {
    if(s.empty()) return false; std::size_t i=0;
    if(s[i]=='-') { if(++i==s.size()) return false; }
    if(s[i]=='0') ++i; else { if(s[i]<'1'||s[i]>'9') return false; while(i<s.size()&&s[i]>='0'&&s[i]<='9')++i; }
    if(i<s.size()&&s[i]=='.') { ++i; auto start=i; while(i<s.size()&&s[i]>='0'&&s[i]<='9')++i; if(i==start)return false; }
    if(i<s.size()&&(s[i]=='e'||s[i]=='E')) { ++i; if(i<s.size()&&(s[i]=='+'||s[i]=='-'))++i; auto start=i; while(i<s.size()&&s[i]>='0'&&s[i]<='9')++i; if(i==start)return false; }
    return i==s.size();
}
void appendUtf8(std::string& out, std::uint32_t c) {
    if(c<=0x7f) out.push_back(static_cast<char>(c));
    else if(c<=0x7ff){out.push_back(static_cast<char>(0xc0|(c>>6)));out.push_back(static_cast<char>(0x80|(c&63)));}
    else if(c<=0xffff){out.push_back(static_cast<char>(0xe0|(c>>12)));out.push_back(static_cast<char>(0x80|((c>>6)&63)));out.push_back(static_cast<char>(0x80|(c&63)));}
    else {out.push_back(static_cast<char>(0xf0|(c>>18)));out.push_back(static_cast<char>(0x80|((c>>12)&63)));out.push_back(static_cast<char>(0x80|((c>>6)&63)));out.push_back(static_cast<char>(0x80|(c&63)));}
}
struct ParseFailure { int kind; std::size_t offset; std::string detail; };
class Parser {
public:
    Parser(std::string input, int maximum): input_(std::move(input)), maximum_(maximum) {}
    std::shared_ptr<Node> run() { if(maximum_<=0) fail(8,"maximum depth must be positive"); space(); auto n=value(0); space(); if(at()!=input_.size())fail(7,"trailing data"); return n; }
private:
    std::string input_; std::size_t offset_=0; int maximum_;
    std::size_t at()const{return offset_;} char peek()const{return offset_<input_.size()?input_[offset_]:'\0';}
    [[noreturn]] void fail(int kind,const char* text){throw ParseFailure{kind,offset_,text};}
    void space(){while(offset_<input_.size()&&(input_[offset_]==' '||input_[offset_]=='\t'||input_[offset_]=='\r'||input_[offset_]=='\n'))++offset_;}
    bool take(char c){if(peek()==c){++offset_;return true;}return false;}
    std::shared_ptr<Node> value(int depth){space(); if(offset_==input_.size())fail(1,"unexpected end"); char c=peek();
        if(c=='n'){literal("null");return scalar(1);} if(c=='t'){literal("true");auto n=scalar(2);n->boolean=true;return n;} if(c=='f'){literal("false");auto n=scalar(2);return n;}
        if(c=='\"')return scalar(3,string()); if(c=='-'||(c>='0'&&c<='9')){auto start=offset_;number();return scalar(4,input_.substr(start,offset_-start));}
        if(c=='[')return array(depth+1); if(c=='{')return object(depth+1); fail(2,"unexpected token"); }
    void literal(const char* text){auto length=std::strlen(text);if(input_.compare(offset_,length,text)!=0)fail(2,"unexpected token");offset_+=length;}
    void number(){auto start=offset_; if(take('-')&&offset_==input_.size())fail(5,"invalid number"); if(take('0')){}else{if(peek()<'1'||peek()>'9')fail(5,"invalid number");while(peek()>='0'&&peek()<='9')++offset_;}
        if(take('.')){auto s=offset_;while(peek()>='0'&&peek()<='9')++offset_;if(s==offset_)fail(5,"invalid number");}
        if(peek()=='e'||peek()=='E'){++offset_;if(peek()=='+'||peek()=='-')++offset_;auto s=offset_;while(peek()>='0'&&peek()<='9')++offset_;if(s==offset_)fail(5,"invalid number");}
        if(!numberValid(input_.substr(start,offset_-start)))fail(5,"invalid number");}
    int hex(){char c=peek();if(c>='0'&&c<='9'){++offset_;return c-'0';}if(c>='a'&&c<='f'){++offset_;return c-'a'+10;}if(c>='A'&&c<='F'){++offset_;return c-'A'+10;}fail(4,"invalid Unicode escape");}
    std::uint32_t unit(){if(offset_+4>input_.size())fail(1,"unexpected end in Unicode escape");std::uint32_t u=0;for(int i=0;i<4;++i)u=(u<<4)|hex();return u;}
    std::string string(){take('\"');std::string out;while(offset_<input_.size()){unsigned char c=input_[offset_++];if(c=='\"')return out;if(c<0x20)fail(2,"control character in string");if(c!='\\'){out.push_back(static_cast<char>(c));continue;}if(offset_==input_.size())fail(1,"unexpected end in escape");char e=input_[offset_++];
        if(e=='\"'||e=='\\'||e=='/')out.push_back(e);else if(e=='b')out.push_back('\b');else if(e=='f')out.push_back('\f');else if(e=='n')out.push_back('\n');else if(e=='r')out.push_back('\r');else if(e=='t')out.push_back('\t');else if(e=='u'){auto u=unit();if(u>=0xd800&&u<=0xdbff){if(offset_+2>input_.size()||input_[offset_]!='\\'||input_[offset_+1]!='u')fail(4,"missing low surrogate");offset_+=2;auto low=unit();if(low<0xdc00||low>0xdfff)fail(4,"invalid low surrogate");u=0x10000+((u-0xd800)<<10)+(low-0xdc00);}else if(u>=0xdc00&&u<=0xdfff)fail(4,"unpaired low surrogate");appendUtf8(out,u);}else fail(3,"invalid escape");}fail(1,"unexpected end in string");}
    std::shared_ptr<Node> array(int depth){if(depth>maximum_)fail(8,"depth limit exceeded");take('[');auto n=scalar(5);space();if(take(']'))return n;while(true){n->children.push_back(value(depth));space();if(take(']'))return n;if(!take(','))fail(2,"expected comma or closing bracket");space();}}
    std::shared_ptr<Node> object(int depth){if(depth>maximum_)fail(8,"depth limit exceeded");take('{');auto n=scalar(6);space();if(take('}'))return n;while(true){if(peek()!='\"')fail(2,"expected object member name");auto name=string();for(auto& old:n->names)if(old==name)fail(6,"duplicate object member");space();if(!take(':'))fail(2,"expected colon");n->names.push_back(std::move(name));n->children.push_back(value(depth));space();if(take('}'))return n;if(!take(','))fail(2,"expected comma or closing brace");space();}}
};
void location(const std::string& text,std::size_t offset,std::int64_t& line,std::int64_t& column){line=1;column=1;for(std::size_t i=0;i<offset;){unsigned char c=text[i];if(c=='\n'){++line;column=1;++i;}else{++column;if(c<0x80)++i;else if((c&0xe0)==0xc0)i+=2;else if((c&0xf0)==0xe0)i+=3;else i+=4;}}}
void escaped(std::string& out,const std::string& value){out.push_back('"');const char* hex="0123456789abcdef";for(unsigned char c:value){switch(c){case'"':out+="\\\"";break;case'\\':out+="\\\\";break;case'\b':out+="\\b";break;case'\f':out+="\\f";break;case'\n':out+="\\n";break;case'\r':out+="\\r";break;case'\t':out+="\\t";break;default:if(c<0x20){out+="\\u00";out.push_back(hex[c>>4]);out.push_back(hex[c&15]);}else out.push_back(static_cast<char>(c));}}out.push_back('"');}
void stringify(const Node& n,bool pretty,int depth,std::string& out){if(n.kind==1){out+="null";return;}if(n.kind==2){out+=n.boolean?"true":"false";return;}if(n.kind==3){escaped(out,n.text);return;}if(n.kind==4){out+=n.text;return;}char open=n.kind==5?'[':'{',close=n.kind==5?']':'}';out.push_back(open);if(n.children.empty()){out.push_back(close);return;}if(pretty)out.push_back('\n');for(std::size_t i=0;i<n.children.size();++i){if(pretty)out.append((depth+1)*2,' ');if(n.kind==6){escaped(out,n.names[i]);out+=pretty?": ":":";}stringify(*n.children[i],pretty,depth+1,out);if(i+1<n.children.size())out.push_back(',');if(pretty)out.push_back('\n');}if(pretty)out.append(depth*2,' ');out.push_back(close);}
}

extern "C" void silexNative_STD_JSON_discard_value(SilexNative_STD_JSON_NativeValue* v){delete v;}
extern "C" void silexNative_STD_JSON_native_release(std::uint64_t value){delete reinterpret_cast<SilexNative_STD_JSON_NativeValue*>(value);}
extern "C" SilexNative_STD_JSON_NativeValue* silexNative_STD_JSON_native_null(){return wrap(scalar(1));}
extern "C" SilexNative_STD_JSON_NativeValue* silexNative_STD_JSON_native_boolean(bool b){auto n=scalar(2);n->boolean=b;return wrap(n);}
extern "C" SilexNative_STD_JSON_NativeValue* silexNative_STD_JSON_native_string(const char* b,std::int64_t l){return wrap(scalar(3,std::string(b,l)));}
extern "C" void silexNative_STD_JSON_native_number_text(const char*b,std::int64_t l,SilexNative_STD_JSON_native_number_textResult*o){std::string s(b,l);if(!numberValid(s)){o->tag=SilexNative_STD_JSON_native_number_textResultTag_failure;o->failure_value={1,copy(s),static_cast<std::int64_t>(s.size())};return;}o->tag=SilexNative_STD_JSON_native_number_textResultTag_success;o->success_value=wrap(scalar(4,s));}
extern "C" SilexNative_STD_JSON_NativeValue* silexNative_STD_JSON_native_number_int(std::int64_t v){return wrap(scalar(4,std::to_string(v)));}
extern "C" SilexNative_STD_JSON_NativeValue* silexNative_STD_JSON_native_number_uint(std::uint64_t v){return wrap(scalar(4,std::to_string(v)));}
extern "C" void silexNative_STD_JSON_native_number_float(double v,SilexNative_STD_JSON_native_number_floatResult*o){if(!std::isfinite(v)){o->tag=SilexNative_STD_JSON_native_number_floatResultTag_failure;o->failure_value={2,nullptr,0};return;}char b[64];auto r=std::to_chars(b,b+64,v,std::chars_format::general);std::string s(b,r.ptr);if(s=="-0")s="0";o->tag=SilexNative_STD_JSON_native_number_floatResultTag_success;o->success_value=wrap(scalar(4,s));}
extern "C" SilexNative_STD_JSON_NativeValue* silexNative_STD_JSON_native_array(){return wrap(scalar(5));}
extern "C" void silexNative_STD_JSON_native_array_append(SilexNative_STD_JSON_NativeValue*t,SilexNative_STD_JSON_NativeValue*v){t->node->children.push_back(v->node);}
extern "C" SilexNative_STD_JSON_NativeValue* silexNative_STD_JSON_native_object(){return wrap(scalar(6));}
extern "C" void silexNative_STD_JSON_native_object_append(SilexNative_STD_JSON_NativeValue*t,const char*b,std::int64_t l,SilexNative_STD_JSON_NativeValue*v,SilexNative_STD_JSON_native_object_appendResult*o){std::string n(b,l);for(auto&x:t->node->names)if(x==n){o->tag=SilexNative_STD_JSON_native_object_appendResultTag_failure;o->failure_value={3,copy(n),l};return;}t->node->names.push_back(n);t->node->children.push_back(v->node);o->tag=SilexNative_STD_JSON_native_object_appendResultTag_success;}
extern "C" std::int64_t silexNative_STD_JSON_native_kind(SilexNative_STD_JSON_NativeValue*v){return v->node->kind;}
extern "C" bool silexNative_STD_JSON_native_boolean_value(SilexNative_STD_JSON_NativeValue*v){return v->node->boolean;}
extern "C" void silexNative_STD_JSON_native_text_value(SilexNative_STD_JSON_NativeValue*v,char**b,std::int64_t*l){*b=copy(v->node->text);*l=v->node->text.size();}
extern "C" std::int64_t silexNative_STD_JSON_native_count(SilexNative_STD_JSON_NativeValue*v){return v->node->children.size();}
extern "C" SilexNative_STD_JSON_NativeValue* silexNative_STD_JSON_native_child(SilexNative_STD_JSON_NativeValue*v,std::int64_t i){return wrap(v->node->children[i]);}
extern "C" void silexNative_STD_JSON_native_member_name(SilexNative_STD_JSON_NativeValue*v,std::int64_t i,char**b,std::int64_t*l){*b=copy(v->node->names[i]);*l=v->node->names[i].size();}
extern "C" void silexNative_STD_JSON_native_parse(const char*b,std::int64_t l,std::int64_t maximum,SilexNative_STD_JSON_native_parseResult*o){std::string text(b,l);try{o->tag=SilexNative_STD_JSON_native_parseResultTag_success;o->success_value=wrap(Parser(text,maximum).run());}catch(const ParseFailure&f){o->tag=SilexNative_STD_JSON_native_parseResultTag_failure;std::int64_t line,column;location(text,f.offset,line,column);o->failure_value={f.kind,static_cast<std::int64_t>(f.offset),line,column,copy(f.detail),static_cast<std::int64_t>(f.detail.size())};}}
extern "C" void silexNative_STD_JSON_native_stringify(SilexNative_STD_JSON_NativeValue*v,bool pretty,char**b,std::int64_t*l){std::string text;stringify(*v->node,pretty,0,text);*b=copy(text);*l=text.size();}
