#ifndef SILEX_NATIVE_STD_H
#define SILEX_NATIVE_STD_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_CONSOLE_DIMENSIONS 1
typedef struct SilexNative_STD_Console_Dimensions {
    int64_t columns;
    int64_t rows;
} SilexNative_STD_Console_Dimensions;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_CONSOLE_SESSION_NATIVEKEYEVENT 1
typedef struct SilexNative_STD_Console_Session_NativeKeyEvent {
    int64_t code;
    bool shift;
    bool control;
    bool alt;
    int64_t number;
    char* text_bytes;
    int64_t text_length;
} SilexNative_STD_Console_Session_NativeKeyEvent;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_ENVIRONMENT_NATIVELOOKUPRESULT 1
typedef struct SilexNative_STD_Environment_NativeLookupResult {
    bool succeeded;
    int64_t error_kind;
    bool present;
    char* value_bytes;
    int64_t value_length;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Environment_NativeLookupResult;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_ENVIRONMENT_NATIVEOPERATIONRESULT 1
typedef struct SilexNative_STD_Environment_NativeOperationResult {
    bool succeeded;
    int64_t error_kind;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Environment_NativeOperationResult;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_PATH_NATIVEPATHRESULT 1
typedef struct SilexNative_STD_Path_NativePathResult {
    bool succeeded;
    bool present;
    bool boolean;
    char* text_bytes;
    int64_t text_length;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Path_NativePathResult;
typedef struct SilexNative_STD_File_File SilexNative_STD_File_File;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_FILE_NATIVEFAILURE 1
typedef struct SilexNative_STD_File_NativeFailure {
    int64_t kind;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_File_NativeFailure;
typedef enum SilexNative_STD_File_native_openResultTag {
    SilexNative_STD_File_native_openResultTag_success = 0,
    SilexNative_STD_File_native_openResultTag_failure = 1
} SilexNative_STD_File_native_openResultTag;

typedef struct SilexNative_STD_File_native_openResult {
    SilexNative_STD_File_native_openResultTag tag;
    SilexNative_STD_File_File* success_value;
    SilexNative_STD_File_NativeFailure failure_value;
} SilexNative_STD_File_native_openResult;

typedef enum SilexNative_STD_File_native_closeResultTag {
    SilexNative_STD_File_native_closeResultTag_success = 0,
    SilexNative_STD_File_native_closeResultTag_failure = 1
} SilexNative_STD_File_native_closeResultTag;

typedef struct SilexNative_STD_File_native_closeResult {
    SilexNative_STD_File_native_closeResultTag tag;
    SilexNative_STD_File_NativeFailure failure_value;
} SilexNative_STD_File_native_closeResult;

typedef enum SilexNative_STD_File_native_readResultTag {
    SilexNative_STD_File_native_readResultTag_success = 0,
    SilexNative_STD_File_native_readResultTag_failure = 1
} SilexNative_STD_File_native_readResultTag;

typedef struct SilexNative_STD_File_native_readResult {
    SilexNative_STD_File_native_readResultTag tag;
    int64_t success_value;
    SilexNative_STD_File_NativeFailure failure_value;
} SilexNative_STD_File_native_readResult;

typedef enum SilexNative_STD_File_native_writeResultTag {
    SilexNative_STD_File_native_writeResultTag_success = 0,
    SilexNative_STD_File_native_writeResultTag_failure = 1
} SilexNative_STD_File_native_writeResultTag;

typedef struct SilexNative_STD_File_native_writeResult {
    SilexNative_STD_File_native_writeResultTag tag;
    int64_t success_value;
    SilexNative_STD_File_NativeFailure failure_value;
} SilexNative_STD_File_native_writeResult;

typedef enum SilexNative_STD_File_native_flushResultTag {
    SilexNative_STD_File_native_flushResultTag_success = 0,
    SilexNative_STD_File_native_flushResultTag_failure = 1
} SilexNative_STD_File_native_flushResultTag;

typedef struct SilexNative_STD_File_native_flushResult {
    SilexNative_STD_File_native_flushResultTag tag;
    SilexNative_STD_File_NativeFailure failure_value;
} SilexNative_STD_File_native_flushResult;

typedef enum SilexNative_STD_File_native_seekResultTag {
    SilexNative_STD_File_native_seekResultTag_success = 0,
    SilexNative_STD_File_native_seekResultTag_failure = 1
} SilexNative_STD_File_native_seekResultTag;

typedef struct SilexNative_STD_File_native_seekResult {
    SilexNative_STD_File_native_seekResultTag tag;
    int64_t success_value;
    SilexNative_STD_File_NativeFailure failure_value;
} SilexNative_STD_File_native_seekResult;

typedef enum SilexNative_STD_File_native_positionResultTag {
    SilexNative_STD_File_native_positionResultTag_success = 0,
    SilexNative_STD_File_native_positionResultTag_failure = 1
} SilexNative_STD_File_native_positionResultTag;

typedef struct SilexNative_STD_File_native_positionResult {
    SilexNative_STD_File_native_positionResultTag tag;
    int64_t success_value;
    SilexNative_STD_File_NativeFailure failure_value;
} SilexNative_STD_File_native_positionResult;

typedef enum SilexNative_STD_File_native_lengthResultTag {
    SilexNative_STD_File_native_lengthResultTag_success = 0,
    SilexNative_STD_File_native_lengthResultTag_failure = 1
} SilexNative_STD_File_native_lengthResultTag;

typedef struct SilexNative_STD_File_native_lengthResult {
    SilexNative_STD_File_native_lengthResultTag tag;
    int64_t success_value;
    SilexNative_STD_File_NativeFailure failure_value;
} SilexNative_STD_File_native_lengthResult;

typedef enum SilexNative_STD_File_native_set_lengthResultTag {
    SilexNative_STD_File_native_set_lengthResultTag_success = 0,
    SilexNative_STD_File_native_set_lengthResultTag_failure = 1
} SilexNative_STD_File_native_set_lengthResultTag;

typedef struct SilexNative_STD_File_native_set_lengthResult {
    SilexNative_STD_File_native_set_lengthResultTag tag;
    SilexNative_STD_File_NativeFailure failure_value;
} SilexNative_STD_File_native_set_lengthResult;

#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_FILESYSTEM_NATIVEMETADATARESULT 1
typedef struct SilexNative_STD_FileSystem_NativeMetadataResult {
    bool succeeded;
    int64_t error_kind;
    int64_t file_kind;
    int64_t size;
    bool readonly;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_FileSystem_NativeMetadataResult;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_FILESYSTEM_NATIVEPATHRESULT 1
typedef struct SilexNative_STD_FileSystem_NativePathResult {
    bool succeeded;
    int64_t error_kind;
    char* path_bytes;
    int64_t path_length;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_FileSystem_NativePathResult;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_FILESYSTEM_NATIVEOPERATIONRESULT 1
typedef struct SilexNative_STD_FileSystem_NativeOperationResult {
    bool succeeded;
    int64_t error_kind;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_FileSystem_NativeOperationResult;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_JSON_NATIVEBUILDFAILURE 1
typedef struct SilexNative_STD_JSON_NativeBuildFailure {
    int64_t kind;
    char* text_bytes;
    int64_t text_length;
} SilexNative_STD_JSON_NativeBuildFailure;
typedef enum SilexNative_STD_JSON_native_number_textResultTag {
    SilexNative_STD_JSON_native_number_textResultTag_success = 0,
    SilexNative_STD_JSON_native_number_textResultTag_failure = 1
} SilexNative_STD_JSON_native_number_textResultTag;

typedef struct SilexNative_STD_JSON_native_number_textResult {
    SilexNative_STD_JSON_native_number_textResultTag tag;
    uint64_t success_value;
    SilexNative_STD_JSON_NativeBuildFailure failure_value;
} SilexNative_STD_JSON_native_number_textResult;

typedef enum SilexNative_STD_JSON_native_number_floatResultTag {
    SilexNative_STD_JSON_native_number_floatResultTag_success = 0,
    SilexNative_STD_JSON_native_number_floatResultTag_failure = 1
} SilexNative_STD_JSON_native_number_floatResultTag;

typedef struct SilexNative_STD_JSON_native_number_floatResult {
    SilexNative_STD_JSON_native_number_floatResultTag tag;
    uint64_t success_value;
    SilexNative_STD_JSON_NativeBuildFailure failure_value;
} SilexNative_STD_JSON_native_number_floatResult;

typedef enum SilexNative_STD_JSON_native_object_appendResultTag {
    SilexNative_STD_JSON_native_object_appendResultTag_success = 0,
    SilexNative_STD_JSON_native_object_appendResultTag_failure = 1
} SilexNative_STD_JSON_native_object_appendResultTag;

typedef struct SilexNative_STD_JSON_native_object_appendResult {
    SilexNative_STD_JSON_native_object_appendResultTag tag;
    SilexNative_STD_JSON_NativeBuildFailure failure_value;
} SilexNative_STD_JSON_native_object_appendResult;

#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_JSON_NATIVEPARSEFAILURE 1
typedef struct SilexNative_STD_JSON_NativeParseFailure {
    int64_t kind;
    int64_t byte_offset;
    int64_t line;
    int64_t column;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_JSON_NativeParseFailure;
typedef enum SilexNative_STD_JSON_native_parseResultTag {
    SilexNative_STD_JSON_native_parseResultTag_success = 0,
    SilexNative_STD_JSON_native_parseResultTag_failure = 1
} SilexNative_STD_JSON_native_parseResultTag;

typedef struct SilexNative_STD_JSON_native_parseResult {
    SilexNative_STD_JSON_native_parseResultTag tag;
    uint64_t success_value;
    SilexNative_STD_JSON_NativeParseFailure failure_value;
} SilexNative_STD_JSON_native_parseResult;

#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_NETWORK_NATIVERESULT 1
typedef struct SilexNative_STD_Network_NativeResult {
    bool succeeded;
    int64_t kind;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Network_NativeResult;
typedef struct SilexNative_STD_Network_TCP_Stream SilexNative_STD_Network_TCP_Stream;
typedef struct SilexNative_STD_Network_TCP_Listener SilexNative_STD_Network_TCP_Listener;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_NETWORK_TCP_NATIVEFAILURE 1
typedef struct SilexNative_STD_Network_TCP_NativeFailure {
    int64_t kind;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Network_TCP_NativeFailure;
typedef enum SilexNative_STD_Network_TCP_native_connectResultTag {
    SilexNative_STD_Network_TCP_native_connectResultTag_success = 0,
    SilexNative_STD_Network_TCP_native_connectResultTag_failure = 1
} SilexNative_STD_Network_TCP_native_connectResultTag;

typedef struct SilexNative_STD_Network_TCP_native_connectResult {
    SilexNative_STD_Network_TCP_native_connectResultTag tag;
    SilexNative_STD_Network_TCP_Stream* success_value;
    SilexNative_STD_Network_TCP_NativeFailure failure_value;
} SilexNative_STD_Network_TCP_native_connectResult;

typedef enum SilexNative_STD_Network_TCP_native_listenResultTag {
    SilexNative_STD_Network_TCP_native_listenResultTag_success = 0,
    SilexNative_STD_Network_TCP_native_listenResultTag_failure = 1
} SilexNative_STD_Network_TCP_native_listenResultTag;

typedef struct SilexNative_STD_Network_TCP_native_listenResult {
    SilexNative_STD_Network_TCP_native_listenResultTag tag;
    SilexNative_STD_Network_TCP_Listener* success_value;
    SilexNative_STD_Network_TCP_NativeFailure failure_value;
} SilexNative_STD_Network_TCP_native_listenResult;

typedef enum SilexNative_STD_Network_TCP_native_acceptResultTag {
    SilexNative_STD_Network_TCP_native_acceptResultTag_success = 0,
    SilexNative_STD_Network_TCP_native_acceptResultTag_failure = 1
} SilexNative_STD_Network_TCP_native_acceptResultTag;

typedef struct SilexNative_STD_Network_TCP_native_acceptResult {
    SilexNative_STD_Network_TCP_native_acceptResultTag tag;
    SilexNative_STD_Network_TCP_Stream* success_value;
    SilexNative_STD_Network_TCP_NativeFailure failure_value;
} SilexNative_STD_Network_TCP_native_acceptResult;

typedef enum SilexNative_STD_Network_TCP_native_readResultTag {
    SilexNative_STD_Network_TCP_native_readResultTag_success = 0,
    SilexNative_STD_Network_TCP_native_readResultTag_failure = 1
} SilexNative_STD_Network_TCP_native_readResultTag;

typedef struct SilexNative_STD_Network_TCP_native_readResult {
    SilexNative_STD_Network_TCP_native_readResultTag tag;
    int64_t success_value;
    SilexNative_STD_Network_TCP_NativeFailure failure_value;
} SilexNative_STD_Network_TCP_native_readResult;

typedef enum SilexNative_STD_Network_TCP_native_writeResultTag {
    SilexNative_STD_Network_TCP_native_writeResultTag_success = 0,
    SilexNative_STD_Network_TCP_native_writeResultTag_failure = 1
} SilexNative_STD_Network_TCP_native_writeResultTag;

typedef struct SilexNative_STD_Network_TCP_native_writeResult {
    SilexNative_STD_Network_TCP_native_writeResultTag tag;
    int64_t success_value;
    SilexNative_STD_Network_TCP_NativeFailure failure_value;
} SilexNative_STD_Network_TCP_native_writeResult;

typedef enum SilexNative_STD_Network_TCP_native_shutdownResultTag {
    SilexNative_STD_Network_TCP_native_shutdownResultTag_success = 0,
    SilexNative_STD_Network_TCP_native_shutdownResultTag_failure = 1
} SilexNative_STD_Network_TCP_native_shutdownResultTag;

typedef struct SilexNative_STD_Network_TCP_native_shutdownResult {
    SilexNative_STD_Network_TCP_native_shutdownResultTag tag;
    SilexNative_STD_Network_TCP_NativeFailure failure_value;
} SilexNative_STD_Network_TCP_native_shutdownResult;

typedef enum SilexNative_STD_Network_TCP_native_close_streamResultTag {
    SilexNative_STD_Network_TCP_native_close_streamResultTag_success = 0,
    SilexNative_STD_Network_TCP_native_close_streamResultTag_failure = 1
} SilexNative_STD_Network_TCP_native_close_streamResultTag;

typedef struct SilexNative_STD_Network_TCP_native_close_streamResult {
    SilexNative_STD_Network_TCP_native_close_streamResultTag tag;
    SilexNative_STD_Network_TCP_NativeFailure failure_value;
} SilexNative_STD_Network_TCP_native_close_streamResult;

typedef enum SilexNative_STD_Network_TCP_native_close_listenerResultTag {
    SilexNative_STD_Network_TCP_native_close_listenerResultTag_success = 0,
    SilexNative_STD_Network_TCP_native_close_listenerResultTag_failure = 1
} SilexNative_STD_Network_TCP_native_close_listenerResultTag;

typedef struct SilexNative_STD_Network_TCP_native_close_listenerResult {
    SilexNative_STD_Network_TCP_native_close_listenerResultTag tag;
    SilexNative_STD_Network_TCP_NativeFailure failure_value;
} SilexNative_STD_Network_TCP_native_close_listenerResult;

#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_NETWORK_TCP_NATIVEOPERATION 1
typedef struct SilexNative_STD_Network_TCP_NativeOperation {
    bool succeeded;
    int64_t kind;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Network_TCP_NativeOperation;
typedef struct SilexNative_STD_Network_UDP_Socket SilexNative_STD_Network_UDP_Socket;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_NETWORK_UDP_NATIVEFAILURE 1
typedef struct SilexNative_STD_Network_UDP_NativeFailure {
    int64_t kind;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Network_UDP_NativeFailure;
typedef enum SilexNative_STD_Network_UDP_native_bindResultTag {
    SilexNative_STD_Network_UDP_native_bindResultTag_success = 0,
    SilexNative_STD_Network_UDP_native_bindResultTag_failure = 1
} SilexNative_STD_Network_UDP_native_bindResultTag;

typedef struct SilexNative_STD_Network_UDP_native_bindResult {
    SilexNative_STD_Network_UDP_native_bindResultTag tag;
    SilexNative_STD_Network_UDP_Socket* success_value;
    SilexNative_STD_Network_UDP_NativeFailure failure_value;
} SilexNative_STD_Network_UDP_native_bindResult;

typedef enum SilexNative_STD_Network_UDP_native_openResultTag {
    SilexNative_STD_Network_UDP_native_openResultTag_success = 0,
    SilexNative_STD_Network_UDP_native_openResultTag_failure = 1
} SilexNative_STD_Network_UDP_native_openResultTag;

typedef struct SilexNative_STD_Network_UDP_native_openResult {
    SilexNative_STD_Network_UDP_native_openResultTag tag;
    SilexNative_STD_Network_UDP_Socket* success_value;
    SilexNative_STD_Network_UDP_NativeFailure failure_value;
} SilexNative_STD_Network_UDP_native_openResult;

typedef enum SilexNative_STD_Network_UDP_native_send_toResultTag {
    SilexNative_STD_Network_UDP_native_send_toResultTag_success = 0,
    SilexNative_STD_Network_UDP_native_send_toResultTag_failure = 1
} SilexNative_STD_Network_UDP_native_send_toResultTag;

typedef struct SilexNative_STD_Network_UDP_native_send_toResult {
    SilexNative_STD_Network_UDP_native_send_toResultTag tag;
    SilexNative_STD_Network_UDP_NativeFailure failure_value;
} SilexNative_STD_Network_UDP_native_send_toResult;

#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_NETWORK_UDP_NATIVERECEIVEOPERATION 1
typedef struct SilexNative_STD_Network_UDP_NativeReceiveOperation {
    bool succeeded;
    int64_t kind;
    char* detail_bytes;
    int64_t detail_length;
    int64_t count;
    bool truncated;
} SilexNative_STD_Network_UDP_NativeReceiveOperation;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_NETWORK_UDP_NATIVEOPERATION 1
typedef struct SilexNative_STD_Network_UDP_NativeOperation {
    bool succeeded;
    int64_t kind;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Network_UDP_NativeOperation;
typedef enum SilexNative_STD_Network_UDP_native_closeResultTag {
    SilexNative_STD_Network_UDP_native_closeResultTag_success = 0,
    SilexNative_STD_Network_UDP_native_closeResultTag_failure = 1
} SilexNative_STD_Network_UDP_native_closeResultTag;

typedef struct SilexNative_STD_Network_UDP_native_closeResult {
    SilexNative_STD_Network_UDP_native_closeResultTag tag;
    SilexNative_STD_Network_UDP_NativeFailure failure_value;
} SilexNative_STD_Network_UDP_native_closeResult;

#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_PROCESS_NATIVEOPERATIONRESULT 1
typedef struct SilexNative_STD_Process_NativeOperationResult {
    bool succeeded;
    int64_t error_kind;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Process_NativeOperationResult;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_PROCESS_NATIVEPATHRESULT 1
typedef struct SilexNative_STD_Process_NativePathResult {
    bool succeeded;
    int64_t error_kind;
    char* path_bytes;
    int64_t path_length;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Process_NativePathResult;
typedef struct SilexNative_STD_Subprocess_NativeCommand SilexNative_STD_Subprocess_NativeCommand;
typedef struct SilexNative_STD_Subprocess_NativeOutput SilexNative_STD_Subprocess_NativeOutput;
#define SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_SUBPROCESS_NATIVEFAILURE 1
typedef struct SilexNative_STD_Subprocess_NativeFailure {
    int64_t kind;
    char* detail_bytes;
    int64_t detail_length;
} SilexNative_STD_Subprocess_NativeFailure;
typedef enum SilexNative_STD_Subprocess_native_createResultTag {
    SilexNative_STD_Subprocess_native_createResultTag_success = 0,
    SilexNative_STD_Subprocess_native_createResultTag_failure = 1
} SilexNative_STD_Subprocess_native_createResultTag;

typedef struct SilexNative_STD_Subprocess_native_createResult {
    SilexNative_STD_Subprocess_native_createResultTag tag;
    SilexNative_STD_Subprocess_NativeCommand* success_value;
    SilexNative_STD_Subprocess_NativeFailure failure_value;
} SilexNative_STD_Subprocess_native_createResult;

typedef enum SilexNative_STD_Subprocess_native_add_argumentResultTag {
    SilexNative_STD_Subprocess_native_add_argumentResultTag_success = 0,
    SilexNative_STD_Subprocess_native_add_argumentResultTag_failure = 1
} SilexNative_STD_Subprocess_native_add_argumentResultTag;

typedef struct SilexNative_STD_Subprocess_native_add_argumentResult {
    SilexNative_STD_Subprocess_native_add_argumentResultTag tag;
    SilexNative_STD_Subprocess_NativeFailure failure_value;
} SilexNative_STD_Subprocess_native_add_argumentResult;

typedef enum SilexNative_STD_Subprocess_native_set_environmentResultTag {
    SilexNative_STD_Subprocess_native_set_environmentResultTag_success = 0,
    SilexNative_STD_Subprocess_native_set_environmentResultTag_failure = 1
} SilexNative_STD_Subprocess_native_set_environmentResultTag;

typedef struct SilexNative_STD_Subprocess_native_set_environmentResult {
    SilexNative_STD_Subprocess_native_set_environmentResultTag tag;
    SilexNative_STD_Subprocess_NativeFailure failure_value;
} SilexNative_STD_Subprocess_native_set_environmentResult;

typedef enum SilexNative_STD_Subprocess_native_remove_environmentResultTag {
    SilexNative_STD_Subprocess_native_remove_environmentResultTag_success = 0,
    SilexNative_STD_Subprocess_native_remove_environmentResultTag_failure = 1
} SilexNative_STD_Subprocess_native_remove_environmentResultTag;

typedef struct SilexNative_STD_Subprocess_native_remove_environmentResult {
    SilexNative_STD_Subprocess_native_remove_environmentResultTag tag;
    SilexNative_STD_Subprocess_NativeFailure failure_value;
} SilexNative_STD_Subprocess_native_remove_environmentResult;

typedef enum SilexNative_STD_Subprocess_native_set_inputResultTag {
    SilexNative_STD_Subprocess_native_set_inputResultTag_success = 0,
    SilexNative_STD_Subprocess_native_set_inputResultTag_failure = 1
} SilexNative_STD_Subprocess_native_set_inputResultTag;

typedef struct SilexNative_STD_Subprocess_native_set_inputResult {
    SilexNative_STD_Subprocess_native_set_inputResultTag tag;
    SilexNative_STD_Subprocess_NativeFailure failure_value;
} SilexNative_STD_Subprocess_native_set_inputResult;

typedef enum SilexNative_STD_Subprocess_native_runResultTag {
    SilexNative_STD_Subprocess_native_runResultTag_success = 0,
    SilexNative_STD_Subprocess_native_runResultTag_failure = 1
} SilexNative_STD_Subprocess_native_runResultTag;

typedef struct SilexNative_STD_Subprocess_native_runResult {
    SilexNative_STD_Subprocess_native_runResultTag tag;
    SilexNative_STD_Subprocess_NativeOutput* success_value;
    SilexNative_STD_Subprocess_NativeFailure failure_value;
} SilexNative_STD_Subprocess_native_runResult;

typedef struct SilexNative_STD_Threading_NativeTaskManager SilexNative_STD_Threading_NativeTaskManager;
typedef struct SilexNative_STD_Threading_NativeTask SilexNative_STD_Threading_NativeTask;
uint64_t silexNative_STD_Collections_Hashing_native_hash_str(const char* silexValue115Bytes, int64_t silexValue115Length);
void silexNative_STD_Console_native_move_cursor(int64_t silexValue128, int64_t silexValue129);
void silexNative_STD_Console_native_set_foreground(int64_t silexValue130);
void silexNative_STD_Console_native_set_background(int64_t silexValue131);
void silexNative_STD_Console_native_enable_style(int64_t silexValue132);
void silexNative_STD_Console_write(const char* silexValue133Bytes, int64_t silexValue133Length);
void silexNative_STD_Console_write_line(const char* silexValue134Bytes, int64_t silexValue134Length);
void silexNative_STD_Console_write_error(const char* silexValue135Bytes, int64_t silexValue135Length);
void silexNative_STD_Console_write_error_line(const char* silexValue136Bytes, int64_t silexValue136Length);
void silexNative_STD_Console_flush(void);
bool silexNative_STD_Console_is_interactive(void);
bool silexNative_STD_Console_get_dimensions(SilexNative_STD_Console_Dimensions* output);
void silexNative_STD_Console_clear_screen(void);
void silexNative_STD_Console_clear_line(void);
void silexNative_STD_Console_show_cursor(void);
void silexNative_STD_Console_hide_cursor(void);
void silexNative_STD_Console_reset_style(void);
bool silexNative_STD_Console_read_line(char** output_bytes, int64_t* output_length);
void silexNative_STD_Console_wait_for_enter(void);
int64_t silexNative_STD_Console_Session_native_session_create(void);
void silexNative_STD_Console_Session_native_session_close(int64_t silexValue148);
bool silexNative_STD_Console_Session_native_session_is_open(int64_t silexValue149);
void silexNative_STD_Console_Session_native_session_read(int64_t silexValue150, SilexNative_STD_Console_Session_NativeKeyEvent* output);
bool silexNative_STD_Console_Session_native_session_poll(int64_t silexValue151, int64_t silexValue152, SilexNative_STD_Console_Session_NativeKeyEvent* output);
void silexNative_STD_Console_Session_native_session_enter_alternate_screen(int64_t silexValue153);
void silexNative_STD_Console_Session_native_session_leave_alternate_screen(int64_t silexValue154);
void silexNative_STD_Text_UTF8_native_bytes(const char* silexValue157Bytes, int64_t silexValue157Length, uint8_t** output_bytes, int64_t* output_length);
void silexNative_STD_Text_UTF8_native_string(const uint8_t* silexValue158Values, int64_t silexValue158Count, char** output_bytes, int64_t* output_length);
void silexNative_STD_Environment_native_get(const char* silexValue185Bytes, int64_t silexValue185Length, SilexNative_STD_Environment_NativeLookupResult* output);
void silexNative_STD_Environment_native_set(const char* silexValue186Bytes, int64_t silexValue186Length, const char* silexValue187Bytes, int64_t silexValue187Length, SilexNative_STD_Environment_NativeOperationResult* output);
void silexNative_STD_Environment_native_remove(const char* silexValue188Bytes, int64_t silexValue188Length, SilexNative_STD_Environment_NativeOperationResult* output);
void silexNative_STD_Environment_native_visit_variables(void (*silexValue189)(void*, int64_t, int64_t), void* silexValue189_context, SilexNative_STD_Environment_NativeOperationResult* output);
bool silexNative_STD_Path_native_windows_semantics(void);
void silexNative_STD_Path_native_validate(const char* silexValue221Bytes, int64_t silexValue221Length, bool silexValue222, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_normalize(const char* silexValue223Bytes, int64_t silexValue223Length, bool silexValue224, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_join(const char* silexValue225Bytes, int64_t silexValue225Length, const char* silexValue226Bytes, int64_t silexValue226Length, bool silexValue227, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_parent(const char* silexValue228Bytes, int64_t silexValue228Length, bool silexValue229, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_name(const char* silexValue230Bytes, int64_t silexValue230Length, bool silexValue231, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_stem(const char* silexValue232Bytes, int64_t silexValue232Length, bool silexValue233, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_extension(const char* silexValue234Bytes, int64_t silexValue234Length, bool silexValue235, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_is_absolute(const char* silexValue236Bytes, int64_t silexValue236Length, bool silexValue237, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_File_discard_file(SilexNative_STD_File_File* silexValue265);
void silexNative_STD_File_native_open(const char* silexValue266Bytes, int64_t silexValue266Length, int64_t silexValue267, int64_t silexValue268, bool silexValue269, SilexNative_STD_File_native_openResult* output);
void silexNative_STD_File_native_close(SilexNative_STD_File_File* silexValue270, SilexNative_STD_File_native_closeResult* output);
void silexNative_STD_File_native_read(SilexNative_STD_File_File* silexValue271, uint8_t* silexValue272Values, int64_t silexValue272Count, SilexNative_STD_File_native_readResult* output);
void silexNative_STD_File_native_write(SilexNative_STD_File_File* silexValue273, const uint8_t* silexValue274Values, int64_t silexValue274Count, SilexNative_STD_File_native_writeResult* output);
void silexNative_STD_File_native_flush(SilexNative_STD_File_File* silexValue275, SilexNative_STD_File_native_flushResult* output);
void silexNative_STD_File_native_seek(SilexNative_STD_File_File* silexValue276, int64_t silexValue277, int64_t silexValue278, SilexNative_STD_File_native_seekResult* output);
void silexNative_STD_File_native_position(SilexNative_STD_File_File* silexValue279, SilexNative_STD_File_native_positionResult* output);
void silexNative_STD_File_native_length(SilexNative_STD_File_File* silexValue280, SilexNative_STD_File_native_lengthResult* output);
void silexNative_STD_File_native_set_length(SilexNative_STD_File_File* silexValue281, int64_t silexValue282, SilexNative_STD_File_native_set_lengthResult* output);
void silexNative_STD_FileSystem_native_metadata(const char* silexValue350Bytes, int64_t silexValue350Length, bool silexValue351, SilexNative_STD_FileSystem_NativeMetadataResult* output);
void silexNative_STD_FileSystem_native_canonicalize(const char* silexValue352Bytes, int64_t silexValue352Length, SilexNative_STD_FileSystem_NativePathResult* output);
void silexNative_STD_FileSystem_native_visit_entries(const char* silexValue353Bytes, int64_t silexValue353Length, void (*silexValue354)(void*, int64_t, int64_t), void* silexValue354_context, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_FileSystem_native_create_directory(const char* silexValue355Bytes, int64_t silexValue355Length, bool silexValue356, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_FileSystem_native_remove(const char* silexValue357Bytes, int64_t silexValue357Length, bool silexValue358, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_FileSystem_native_rename(const char* silexValue359Bytes, int64_t silexValue359Length, const char* silexValue360Bytes, int64_t silexValue360Length, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_FileSystem_native_copy_file(const char* silexValue361Bytes, int64_t silexValue361Length, const char* silexValue362Bytes, int64_t silexValue362Length, bool silexValue363, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_FileSystem_native_set_readonly(const char* silexValue364Bytes, int64_t silexValue364Length, bool silexValue365, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_JSON_native_release(uint64_t silexValue412);
uint64_t silexNative_STD_JSON_native_null(void);
uint64_t silexNative_STD_JSON_native_boolean(bool silexValue413);
uint64_t silexNative_STD_JSON_native_string(const char* silexValue414Bytes, int64_t silexValue414Length);
void silexNative_STD_JSON_native_number_text(const char* silexValue415Bytes, int64_t silexValue415Length, SilexNative_STD_JSON_native_number_textResult* output);
uint64_t silexNative_STD_JSON_native_number_int(int64_t silexValue416);
uint64_t silexNative_STD_JSON_native_number_uint(uint64_t silexValue417);
void silexNative_STD_JSON_native_number_float(double silexValue418, SilexNative_STD_JSON_native_number_floatResult* output);
uint64_t silexNative_STD_JSON_native_array(void);
void silexNative_STD_JSON_native_array_append(uint64_t silexValue419, uint64_t silexValue420);
uint64_t silexNative_STD_JSON_native_object(void);
void silexNative_STD_JSON_native_object_append(uint64_t silexValue421, const char* silexValue422Bytes, int64_t silexValue422Length, uint64_t silexValue423, SilexNative_STD_JSON_native_object_appendResult* output);
int64_t silexNative_STD_JSON_native_kind(uint64_t silexValue424);
bool silexNative_STD_JSON_native_boolean_value(uint64_t silexValue425);
void silexNative_STD_JSON_native_text_value(uint64_t silexValue426, char** output_bytes, int64_t* output_length);
int64_t silexNative_STD_JSON_native_count(uint64_t silexValue427);
uint64_t silexNative_STD_JSON_native_child(uint64_t silexValue428, int64_t silexValue429);
void silexNative_STD_JSON_native_member_name(uint64_t silexValue430, int64_t silexValue431, char** output_bytes, int64_t* output_length);
void silexNative_STD_JSON_native_parse(const char* silexValue432Bytes, int64_t silexValue432Length, int64_t silexValue433, SilexNative_STD_JSON_native_parseResult* output);
void silexNative_STD_JSON_native_stringify(uint64_t silexValue434, bool silexValue435, char** output_bytes, int64_t* output_length);
float silexNative_STD_Math_sqrt(float silexValue445);
float silexNative_STD_Math_sin(float silexValue446);
float silexNative_STD_Math_cos(float silexValue447);
float silexNative_STD_Math_tan(float silexValue448);
float silexNative_STD_Math_asin(float silexValue449);
float silexNative_STD_Math_atan2(float silexValue450, float silexValue451);
void silexNative_STD_Network_native_parse_ip(const char* silexValue474Bytes, int64_t silexValue474Length, void (*silexValue475)(void*, int64_t), void* silexValue475_context, SilexNative_STD_Network_NativeResult* output);
void silexNative_STD_Network_native_format_ip(int64_t silexValue476, const uint8_t* silexValue477Values, int64_t silexValue477Count, char** output_bytes, int64_t* output_length);
void silexNative_STD_Network_native_format_endpoint(int64_t silexValue478, int64_t silexValue479, int64_t silexValue480, const uint8_t* silexValue481Values, int64_t silexValue481Count, char** output_bytes, int64_t* output_length);
void silexNative_STD_Network_native_resolve(const char* silexValue482Bytes, int64_t silexValue482Length, int64_t silexValue483, int64_t silexValue484, int64_t silexValue485, void (*silexValue486)(void*, int64_t), void* silexValue486_context, SilexNative_STD_Network_NativeResult* output);
int64_t silexNative_STD_Time_Internal_native_monotonic_microseconds(void);
void silexNative_STD_Network_TCP_discard_stream(SilexNative_STD_Network_TCP_Stream* silexValue541);
void silexNative_STD_Network_TCP_discard_listener(SilexNative_STD_Network_TCP_Listener* silexValue542);
void silexNative_STD_Network_TCP_native_connect(int64_t silexValue543, const uint8_t* silexValue544Values, int64_t silexValue544Count, int64_t silexValue545, int64_t silexValue546, int64_t silexValue547, int64_t silexValue548, int64_t silexValue549, SilexNative_STD_Network_TCP_native_connectResult* output);
void silexNative_STD_Network_TCP_native_listen(int64_t silexValue550, const uint8_t* silexValue551Values, int64_t silexValue551Count, int64_t silexValue552, int64_t silexValue553, int64_t silexValue554, SilexNative_STD_Network_TCP_native_listenResult* output);
void silexNative_STD_Network_TCP_native_accept(SilexNative_STD_Network_TCP_Listener* silexValue555, int64_t silexValue556, int64_t silexValue557, int64_t silexValue558, SilexNative_STD_Network_TCP_native_acceptResult* output);
void silexNative_STD_Network_TCP_native_read(SilexNative_STD_Network_TCP_Stream* silexValue559, uint8_t* silexValue560Values, int64_t silexValue560Count, SilexNative_STD_Network_TCP_native_readResult* output);
void silexNative_STD_Network_TCP_native_write(SilexNative_STD_Network_TCP_Stream* silexValue561, const uint8_t* silexValue562Values, int64_t silexValue562Count, SilexNative_STD_Network_TCP_native_writeResult* output);
void silexNative_STD_Network_TCP_native_shutdown(SilexNative_STD_Network_TCP_Stream* silexValue563, bool silexValue564, SilexNative_STD_Network_TCP_native_shutdownResult* output);
void silexNative_STD_Network_TCP_native_close_stream(SilexNative_STD_Network_TCP_Stream* silexValue565, SilexNative_STD_Network_TCP_native_close_streamResult* output);
void silexNative_STD_Network_TCP_native_close_listener(SilexNative_STD_Network_TCP_Listener* silexValue566, SilexNative_STD_Network_TCP_native_close_listenerResult* output);
void silexNative_STD_Network_TCP_native_stream_endpoint(const SilexNative_STD_Network_TCP_Stream* silexValue567, bool silexValue568, void (*silexValue569)(void*, int64_t), void* silexValue569_context, SilexNative_STD_Network_TCP_NativeOperation* output);
void silexNative_STD_Network_TCP_native_listener_endpoint(const SilexNative_STD_Network_TCP_Listener* silexValue570, void (*silexValue571)(void*, int64_t), void* silexValue571_context, SilexNative_STD_Network_TCP_NativeOperation* output);
void silexNative_STD_Network_TCP_native_subject(const char* silexValue572Bytes, int64_t silexValue572Length, int64_t silexValue573, char** output_bytes, int64_t* output_length);
void silexNative_STD_Network_UDP_discard_socket(SilexNative_STD_Network_UDP_Socket* silexValue703);
void silexNative_STD_Network_UDP_native_bind(int64_t silexValue704, const uint8_t* silexValue705Values, int64_t silexValue705Count, int64_t silexValue706, int64_t silexValue707, int64_t silexValue708, int64_t silexValue709, SilexNative_STD_Network_UDP_native_bindResult* output);
void silexNative_STD_Network_UDP_native_open(int64_t silexValue710, int64_t silexValue711, int64_t silexValue712, SilexNative_STD_Network_UDP_native_openResult* output);
void silexNative_STD_Network_UDP_native_send_to(SilexNative_STD_Network_UDP_Socket* silexValue713, const uint8_t* silexValue714Values, int64_t silexValue714Count, int64_t silexValue715, const uint8_t* silexValue716Values, int64_t silexValue716Count, int64_t silexValue717, int64_t silexValue718, SilexNative_STD_Network_UDP_native_send_toResult* output);
void silexNative_STD_Network_UDP_native_receive_from(SilexNative_STD_Network_UDP_Socket* silexValue719, uint8_t* silexValue720Values, int64_t silexValue720Count, void (*silexValue721)(void*, int64_t), void* silexValue721_context, SilexNative_STD_Network_UDP_NativeReceiveOperation* output);
void silexNative_STD_Network_UDP_native_local_endpoint(const SilexNative_STD_Network_UDP_Socket* silexValue722, void (*silexValue723)(void*, int64_t), void* silexValue723_context, SilexNative_STD_Network_UDP_NativeOperation* output);
void silexNative_STD_Network_UDP_native_close(SilexNative_STD_Network_UDP_Socket* silexValue724, SilexNative_STD_Network_UDP_native_closeResult* output);
void silexNative_STD_Process_native_visit_arguments(void (*silexValue811)(void*, int64_t, int64_t), void* silexValue811_context, SilexNative_STD_Process_NativeOperationResult* output);
void silexNative_STD_Process_native_current_directory(SilexNative_STD_Process_NativePathResult* output);
void silexNative_STD_Process_native_set_current_directory(const char* silexValue812Bytes, int64_t silexValue812Length, SilexNative_STD_Process_NativeOperationResult* output);
void silexNative_STD_Process_native_executable_path(SilexNative_STD_Process_NativePathResult* output);
uint64_t silexNative_STD_Process_native_id(void);
int64_t silexNative_STD_Randomizer_native_seed(void);
void silexNative_STD_Subprocess_discard_command(SilexNative_STD_Subprocess_NativeCommand* silexValue839);
void silexNative_STD_Subprocess_discard_output(SilexNative_STD_Subprocess_NativeOutput* silexValue840);
void silexNative_STD_Subprocess_native_create(const char* silexValue841Bytes, int64_t silexValue841Length, bool silexValue842, const char* silexValue843Bytes, int64_t silexValue843Length, bool silexValue844, int64_t silexValue845, SilexNative_STD_Subprocess_native_createResult* output);
void silexNative_STD_Subprocess_native_add_argument(SilexNative_STD_Subprocess_NativeCommand* silexValue846, const char* silexValue847Bytes, int64_t silexValue847Length, SilexNative_STD_Subprocess_native_add_argumentResult* output);
void silexNative_STD_Subprocess_native_set_environment(SilexNative_STD_Subprocess_NativeCommand* silexValue848, const char* silexValue849Bytes, int64_t silexValue849Length, const char* silexValue850Bytes, int64_t silexValue850Length, SilexNative_STD_Subprocess_native_set_environmentResult* output);
void silexNative_STD_Subprocess_native_remove_environment(SilexNative_STD_Subprocess_NativeCommand* silexValue851, const char* silexValue852Bytes, int64_t silexValue852Length, SilexNative_STD_Subprocess_native_remove_environmentResult* output);
void silexNative_STD_Subprocess_native_set_input(SilexNative_STD_Subprocess_NativeCommand* silexValue853, const uint8_t* silexValue854Values, int64_t silexValue854Count, SilexNative_STD_Subprocess_native_set_inputResult* output);
void silexNative_STD_Subprocess_native_run(SilexNative_STD_Subprocess_NativeCommand* silexValue855, SilexNative_STD_Subprocess_native_runResult* output);
int64_t silexNative_STD_Subprocess_native_status_kind(SilexNative_STD_Subprocess_NativeOutput* silexValue856);
int64_t silexNative_STD_Subprocess_native_status_code(SilexNative_STD_Subprocess_NativeOutput* silexValue857);
void silexNative_STD_Subprocess_native_visit_bytes(SilexNative_STD_Subprocess_NativeOutput* silexValue858, int64_t silexValue859, void (*silexValue860)(void*, int64_t), void* silexValue860_context);
void silexNative_STD_Text_native_normalize(const char* silexValue900Bytes, int64_t silexValue900Length, int64_t silexValue901, char** output_bytes, int64_t* output_length);
void silexNative_STD_Text_native_lowercase(const char* silexValue902Bytes, int64_t silexValue902Length, char** output_bytes, int64_t* output_length);
void silexNative_STD_Text_native_uppercase(const char* silexValue903Bytes, int64_t silexValue903Length, char** output_bytes, int64_t* output_length);
void silexNative_STD_Text_native_case_fold(const char* silexValue904Bytes, int64_t silexValue904Length, char** output_bytes, int64_t* output_length);
void silexNative_STD_Text_Grapheme_native_visit_boundaries(const char* silexValue914Bytes, int64_t silexValue914Length, void (*silexValue915)(void*, int64_t), void* silexValue915_context);
void silexNative_STD_Text_Grapheme_native_slice(const char* silexValue916Bytes, int64_t silexValue916Length, int64_t silexValue917, int64_t silexValue918, char** output_bytes, int64_t* output_length);
void silexNative_STD_Threading_native_destroy_manager(SilexNative_STD_Threading_NativeTaskManager* silexValue928);
void silexNative_STD_Threading_native_destroy_task(SilexNative_STD_Threading_NativeTask* silexValue929);
int64_t silexNative_STD_Threading_native_logical_processor_count(void);
SilexNative_STD_Threading_NativeTaskManager* silexNative_STD_Threading_native_create_manager(int64_t silexValue930);
SilexNative_STD_Threading_NativeTask* silexNative_STD_Threading_native_submit(const SilexNative_STD_Threading_NativeTaskManager* silexValue931, void (*silexValue932)(void*), void* silexValue932_context);
void silexNative_STD_Threading_native_complete(const SilexNative_STD_Threading_NativeTask* silexValue933);

#ifdef __cplusplus
}
#endif

#endif
