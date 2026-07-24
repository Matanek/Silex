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
uint64_t silexNative_STD_Collections_Hashing_native_hash_str(const char* silexValue114Bytes, int64_t silexValue114Length);
void silexNative_STD_Console_native_move_cursor(int64_t silexValue139, int64_t silexValue140);
void silexNative_STD_Console_native_set_foreground(int64_t silexValue141);
void silexNative_STD_Console_native_set_background(int64_t silexValue142);
void silexNative_STD_Console_native_enable_style(int64_t silexValue143);
void silexNative_STD_Console_write(const char* silexValue144Bytes, int64_t silexValue144Length);
void silexNative_STD_Console_write_line(const char* silexValue145Bytes, int64_t silexValue145Length);
void silexNative_STD_Console_write_error(const char* silexValue146Bytes, int64_t silexValue146Length);
void silexNative_STD_Console_write_error_line(const char* silexValue147Bytes, int64_t silexValue147Length);
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
void silexNative_STD_Console_Session_native_session_close(int64_t silexValue159);
bool silexNative_STD_Console_Session_native_session_is_open(int64_t silexValue160);
void silexNative_STD_Console_Session_native_session_read(int64_t silexValue161, SilexNative_STD_Console_Session_NativeKeyEvent* output);
bool silexNative_STD_Console_Session_native_session_poll(int64_t silexValue162, int64_t silexValue163, SilexNative_STD_Console_Session_NativeKeyEvent* output);
void silexNative_STD_Console_Session_native_session_enter_alternate_screen(int64_t silexValue164);
void silexNative_STD_Console_Session_native_session_leave_alternate_screen(int64_t silexValue165);
void silexNative_STD_Text_UTF8_native_bytes(const char* silexValue168Bytes, int64_t silexValue168Length, uint8_t** output_bytes, int64_t* output_length);
void silexNative_STD_Text_UTF8_native_string(const uint8_t* silexValue169Values, int64_t silexValue169Count, char** output_bytes, int64_t* output_length);
void silexNative_STD_Environment_native_get(const char* silexValue196Bytes, int64_t silexValue196Length, SilexNative_STD_Environment_NativeLookupResult* output);
void silexNative_STD_Environment_native_set(const char* silexValue197Bytes, int64_t silexValue197Length, const char* silexValue198Bytes, int64_t silexValue198Length, SilexNative_STD_Environment_NativeOperationResult* output);
void silexNative_STD_Environment_native_remove(const char* silexValue199Bytes, int64_t silexValue199Length, SilexNative_STD_Environment_NativeOperationResult* output);
void silexNative_STD_Environment_native_visit_variables(void (*silexValue200)(void*, int64_t, int64_t), void* silexValue200_context, SilexNative_STD_Environment_NativeOperationResult* output);
bool silexNative_STD_Path_native_windows_semantics(void);
void silexNative_STD_Path_native_validate(const char* silexValue232Bytes, int64_t silexValue232Length, bool silexValue233, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_normalize(const char* silexValue234Bytes, int64_t silexValue234Length, bool silexValue235, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_join(const char* silexValue236Bytes, int64_t silexValue236Length, const char* silexValue237Bytes, int64_t silexValue237Length, bool silexValue238, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_parent(const char* silexValue239Bytes, int64_t silexValue239Length, bool silexValue240, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_name(const char* silexValue241Bytes, int64_t silexValue241Length, bool silexValue242, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_stem(const char* silexValue243Bytes, int64_t silexValue243Length, bool silexValue244, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_extension(const char* silexValue245Bytes, int64_t silexValue245Length, bool silexValue246, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_Path_native_is_absolute(const char* silexValue247Bytes, int64_t silexValue247Length, bool silexValue248, SilexNative_STD_Path_NativePathResult* output);
void silexNative_STD_File_discard_file(SilexNative_STD_File_File* silexValue276);
void silexNative_STD_File_native_open(const char* silexValue277Bytes, int64_t silexValue277Length, int64_t silexValue278, int64_t silexValue279, bool silexValue280, SilexNative_STD_File_native_openResult* output);
void silexNative_STD_File_native_close(SilexNative_STD_File_File* silexValue281, SilexNative_STD_File_native_closeResult* output);
void silexNative_STD_File_native_read(SilexNative_STD_File_File* silexValue282, uint8_t* silexValue283Values, int64_t silexValue283Count, SilexNative_STD_File_native_readResult* output);
void silexNative_STD_File_native_write(SilexNative_STD_File_File* silexValue284, const uint8_t* silexValue285Values, int64_t silexValue285Count, SilexNative_STD_File_native_writeResult* output);
void silexNative_STD_File_native_flush(SilexNative_STD_File_File* silexValue286, SilexNative_STD_File_native_flushResult* output);
void silexNative_STD_File_native_seek(SilexNative_STD_File_File* silexValue287, int64_t silexValue288, int64_t silexValue289, SilexNative_STD_File_native_seekResult* output);
void silexNative_STD_File_native_position(SilexNative_STD_File_File* silexValue290, SilexNative_STD_File_native_positionResult* output);
void silexNative_STD_File_native_length(SilexNative_STD_File_File* silexValue291, SilexNative_STD_File_native_lengthResult* output);
void silexNative_STD_File_native_set_length(SilexNative_STD_File_File* silexValue292, int64_t silexValue293, SilexNative_STD_File_native_set_lengthResult* output);
void silexNative_STD_FileSystem_native_metadata(const char* silexValue361Bytes, int64_t silexValue361Length, bool silexValue362, SilexNative_STD_FileSystem_NativeMetadataResult* output);
void silexNative_STD_FileSystem_native_canonicalize(const char* silexValue363Bytes, int64_t silexValue363Length, SilexNative_STD_FileSystem_NativePathResult* output);
void silexNative_STD_FileSystem_native_visit_entries(const char* silexValue364Bytes, int64_t silexValue364Length, void (*silexValue365)(void*, int64_t, int64_t), void* silexValue365_context, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_FileSystem_native_create_directory(const char* silexValue366Bytes, int64_t silexValue366Length, bool silexValue367, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_FileSystem_native_remove(const char* silexValue368Bytes, int64_t silexValue368Length, bool silexValue369, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_FileSystem_native_rename(const char* silexValue370Bytes, int64_t silexValue370Length, const char* silexValue371Bytes, int64_t silexValue371Length, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_FileSystem_native_copy_file(const char* silexValue372Bytes, int64_t silexValue372Length, const char* silexValue373Bytes, int64_t silexValue373Length, bool silexValue374, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_FileSystem_native_set_readonly(const char* silexValue375Bytes, int64_t silexValue375Length, bool silexValue376, SilexNative_STD_FileSystem_NativeOperationResult* output);
void silexNative_STD_JSON_native_release(uint64_t silexValue423);
uint64_t silexNative_STD_JSON_native_null(void);
uint64_t silexNative_STD_JSON_native_boolean(bool silexValue424);
uint64_t silexNative_STD_JSON_native_string(const char* silexValue425Bytes, int64_t silexValue425Length);
void silexNative_STD_JSON_native_number_text(const char* silexValue426Bytes, int64_t silexValue426Length, SilexNative_STD_JSON_native_number_textResult* output);
uint64_t silexNative_STD_JSON_native_number_int(int64_t silexValue427);
uint64_t silexNative_STD_JSON_native_number_uint(uint64_t silexValue428);
void silexNative_STD_JSON_native_number_float(double silexValue429, SilexNative_STD_JSON_native_number_floatResult* output);
uint64_t silexNative_STD_JSON_native_array(void);
void silexNative_STD_JSON_native_array_append(uint64_t silexValue430, uint64_t silexValue431);
uint64_t silexNative_STD_JSON_native_object(void);
void silexNative_STD_JSON_native_object_append(uint64_t silexValue432, const char* silexValue433Bytes, int64_t silexValue433Length, uint64_t silexValue434, SilexNative_STD_JSON_native_object_appendResult* output);
int64_t silexNative_STD_JSON_native_kind(uint64_t silexValue435);
bool silexNative_STD_JSON_native_boolean_value(uint64_t silexValue436);
void silexNative_STD_JSON_native_text_value(uint64_t silexValue437, char** output_bytes, int64_t* output_length);
int64_t silexNative_STD_JSON_native_count(uint64_t silexValue438);
uint64_t silexNative_STD_JSON_native_child(uint64_t silexValue439, int64_t silexValue440);
void silexNative_STD_JSON_native_member_name(uint64_t silexValue441, int64_t silexValue442, char** output_bytes, int64_t* output_length);
void silexNative_STD_JSON_native_parse(const char* silexValue443Bytes, int64_t silexValue443Length, int64_t silexValue444, SilexNative_STD_JSON_native_parseResult* output);
void silexNative_STD_JSON_native_stringify(uint64_t silexValue445, bool silexValue446, char** output_bytes, int64_t* output_length);
float silexNative_STD_Math_sqrt(float silexValue456);
float silexNative_STD_Math_sin(float silexValue457);
float silexNative_STD_Math_cos(float silexValue458);
float silexNative_STD_Math_tan(float silexValue459);
float silexNative_STD_Math_asin(float silexValue460);
float silexNative_STD_Math_atan2(float silexValue461, float silexValue462);
void silexNative_STD_Network_native_parse_ip(const char* silexValue485Bytes, int64_t silexValue485Length, void (*silexValue486)(void*, int64_t), void* silexValue486_context, SilexNative_STD_Network_NativeResult* output);
void silexNative_STD_Network_native_format_ip(int64_t silexValue487, const uint8_t* silexValue488Values, int64_t silexValue488Count, char** output_bytes, int64_t* output_length);
void silexNative_STD_Network_native_format_endpoint(int64_t silexValue489, int64_t silexValue490, int64_t silexValue491, const uint8_t* silexValue492Values, int64_t silexValue492Count, char** output_bytes, int64_t* output_length);
void silexNative_STD_Network_native_resolve(const char* silexValue493Bytes, int64_t silexValue493Length, int64_t silexValue494, int64_t silexValue495, int64_t silexValue496, void (*silexValue497)(void*, int64_t), void* silexValue497_context, SilexNative_STD_Network_NativeResult* output);
int64_t silexNative_STD_Time_Internal_native_monotonic_microseconds(void);
void silexNative_STD_Network_TCP_discard_stream(SilexNative_STD_Network_TCP_Stream* silexValue552);
void silexNative_STD_Network_TCP_discard_listener(SilexNative_STD_Network_TCP_Listener* silexValue553);
void silexNative_STD_Network_TCP_native_connect(int64_t silexValue554, const uint8_t* silexValue555Values, int64_t silexValue555Count, int64_t silexValue556, int64_t silexValue557, int64_t silexValue558, int64_t silexValue559, int64_t silexValue560, SilexNative_STD_Network_TCP_native_connectResult* output);
void silexNative_STD_Network_TCP_native_listen(int64_t silexValue561, const uint8_t* silexValue562Values, int64_t silexValue562Count, int64_t silexValue563, int64_t silexValue564, int64_t silexValue565, SilexNative_STD_Network_TCP_native_listenResult* output);
void silexNative_STD_Network_TCP_native_accept(SilexNative_STD_Network_TCP_Listener* silexValue566, int64_t silexValue567, int64_t silexValue568, int64_t silexValue569, SilexNative_STD_Network_TCP_native_acceptResult* output);
void silexNative_STD_Network_TCP_native_read(SilexNative_STD_Network_TCP_Stream* silexValue570, uint8_t* silexValue571Values, int64_t silexValue571Count, SilexNative_STD_Network_TCP_native_readResult* output);
void silexNative_STD_Network_TCP_native_write(SilexNative_STD_Network_TCP_Stream* silexValue572, const uint8_t* silexValue573Values, int64_t silexValue573Count, SilexNative_STD_Network_TCP_native_writeResult* output);
void silexNative_STD_Network_TCP_native_shutdown(SilexNative_STD_Network_TCP_Stream* silexValue574, bool silexValue575, SilexNative_STD_Network_TCP_native_shutdownResult* output);
void silexNative_STD_Network_TCP_native_close_stream(SilexNative_STD_Network_TCP_Stream* silexValue576, SilexNative_STD_Network_TCP_native_close_streamResult* output);
void silexNative_STD_Network_TCP_native_close_listener(SilexNative_STD_Network_TCP_Listener* silexValue577, SilexNative_STD_Network_TCP_native_close_listenerResult* output);
void silexNative_STD_Network_TCP_native_stream_endpoint(const SilexNative_STD_Network_TCP_Stream* silexValue578, bool silexValue579, void (*silexValue580)(void*, int64_t), void* silexValue580_context, SilexNative_STD_Network_TCP_NativeOperation* output);
void silexNative_STD_Network_TCP_native_listener_endpoint(const SilexNative_STD_Network_TCP_Listener* silexValue581, void (*silexValue582)(void*, int64_t), void* silexValue582_context, SilexNative_STD_Network_TCP_NativeOperation* output);
void silexNative_STD_Network_TCP_native_subject(const char* silexValue583Bytes, int64_t silexValue583Length, int64_t silexValue584, char** output_bytes, int64_t* output_length);
void silexNative_STD_Network_UDP_discard_socket(SilexNative_STD_Network_UDP_Socket* silexValue714);
void silexNative_STD_Network_UDP_native_bind(int64_t silexValue715, const uint8_t* silexValue716Values, int64_t silexValue716Count, int64_t silexValue717, int64_t silexValue718, int64_t silexValue719, int64_t silexValue720, SilexNative_STD_Network_UDP_native_bindResult* output);
void silexNative_STD_Network_UDP_native_open(int64_t silexValue721, int64_t silexValue722, int64_t silexValue723, SilexNative_STD_Network_UDP_native_openResult* output);
void silexNative_STD_Network_UDP_native_send_to(SilexNative_STD_Network_UDP_Socket* silexValue724, const uint8_t* silexValue725Values, int64_t silexValue725Count, int64_t silexValue726, const uint8_t* silexValue727Values, int64_t silexValue727Count, int64_t silexValue728, int64_t silexValue729, SilexNative_STD_Network_UDP_native_send_toResult* output);
void silexNative_STD_Network_UDP_native_receive_from(SilexNative_STD_Network_UDP_Socket* silexValue730, uint8_t* silexValue731Values, int64_t silexValue731Count, void (*silexValue732)(void*, int64_t), void* silexValue732_context, SilexNative_STD_Network_UDP_NativeReceiveOperation* output);
void silexNative_STD_Network_UDP_native_local_endpoint(const SilexNative_STD_Network_UDP_Socket* silexValue733, void (*silexValue734)(void*, int64_t), void* silexValue734_context, SilexNative_STD_Network_UDP_NativeOperation* output);
void silexNative_STD_Network_UDP_native_close(SilexNative_STD_Network_UDP_Socket* silexValue735, SilexNative_STD_Network_UDP_native_closeResult* output);
void silexNative_STD_Process_native_visit_arguments(void (*silexValue822)(void*, int64_t, int64_t), void* silexValue822_context, SilexNative_STD_Process_NativeOperationResult* output);
void silexNative_STD_Process_native_current_directory(SilexNative_STD_Process_NativePathResult* output);
void silexNative_STD_Process_native_set_current_directory(const char* silexValue823Bytes, int64_t silexValue823Length, SilexNative_STD_Process_NativeOperationResult* output);
void silexNative_STD_Process_native_executable_path(SilexNative_STD_Process_NativePathResult* output);
uint64_t silexNative_STD_Process_native_id(void);
int64_t silexNative_STD_Randomizer_native_seed(void);
void silexNative_STD_Subprocess_discard_command(SilexNative_STD_Subprocess_NativeCommand* silexValue850);
void silexNative_STD_Subprocess_discard_output(SilexNative_STD_Subprocess_NativeOutput* silexValue851);
void silexNative_STD_Subprocess_native_create(const char* silexValue852Bytes, int64_t silexValue852Length, bool silexValue853, const char* silexValue854Bytes, int64_t silexValue854Length, bool silexValue855, int64_t silexValue856, SilexNative_STD_Subprocess_native_createResult* output);
void silexNative_STD_Subprocess_native_add_argument(SilexNative_STD_Subprocess_NativeCommand* silexValue857, const char* silexValue858Bytes, int64_t silexValue858Length, SilexNative_STD_Subprocess_native_add_argumentResult* output);
void silexNative_STD_Subprocess_native_set_environment(SilexNative_STD_Subprocess_NativeCommand* silexValue859, const char* silexValue860Bytes, int64_t silexValue860Length, const char* silexValue861Bytes, int64_t silexValue861Length, SilexNative_STD_Subprocess_native_set_environmentResult* output);
void silexNative_STD_Subprocess_native_remove_environment(SilexNative_STD_Subprocess_NativeCommand* silexValue862, const char* silexValue863Bytes, int64_t silexValue863Length, SilexNative_STD_Subprocess_native_remove_environmentResult* output);
void silexNative_STD_Subprocess_native_set_input(SilexNative_STD_Subprocess_NativeCommand* silexValue864, const uint8_t* silexValue865Values, int64_t silexValue865Count, SilexNative_STD_Subprocess_native_set_inputResult* output);
void silexNative_STD_Subprocess_native_run(SilexNative_STD_Subprocess_NativeCommand* silexValue866, SilexNative_STD_Subprocess_native_runResult* output);
int64_t silexNative_STD_Subprocess_native_status_kind(SilexNative_STD_Subprocess_NativeOutput* silexValue867);
int64_t silexNative_STD_Subprocess_native_status_code(SilexNative_STD_Subprocess_NativeOutput* silexValue868);
void silexNative_STD_Subprocess_native_visit_bytes(SilexNative_STD_Subprocess_NativeOutput* silexValue869, int64_t silexValue870, void (*silexValue871)(void*, int64_t), void* silexValue871_context);
void silexNative_STD_Text_native_normalize(const char* silexValue911Bytes, int64_t silexValue911Length, int64_t silexValue912, char** output_bytes, int64_t* output_length);
void silexNative_STD_Text_native_lowercase(const char* silexValue913Bytes, int64_t silexValue913Length, char** output_bytes, int64_t* output_length);
void silexNative_STD_Text_native_uppercase(const char* silexValue914Bytes, int64_t silexValue914Length, char** output_bytes, int64_t* output_length);
void silexNative_STD_Text_native_case_fold(const char* silexValue915Bytes, int64_t silexValue915Length, char** output_bytes, int64_t* output_length);
void silexNative_STD_Text_Grapheme_native_visit_boundaries(const char* silexValue925Bytes, int64_t silexValue925Length, void (*silexValue926)(void*, int64_t), void* silexValue926_context);
void silexNative_STD_Text_Grapheme_native_slice(const char* silexValue927Bytes, int64_t silexValue927Length, int64_t silexValue928, int64_t silexValue929, char** output_bytes, int64_t* output_length);
void silexNative_STD_Threading_native_destroy_manager(SilexNative_STD_Threading_NativeTaskManager* silexValue939);
void silexNative_STD_Threading_native_destroy_task(SilexNative_STD_Threading_NativeTask* silexValue940);
int64_t silexNative_STD_Threading_native_logical_processor_count(void);
SilexNative_STD_Threading_NativeTaskManager* silexNative_STD_Threading_native_create_manager(int64_t silexValue941);
SilexNative_STD_Threading_NativeTask* silexNative_STD_Threading_native_submit(const SilexNative_STD_Threading_NativeTaskManager* silexValue942, void (*silexValue943)(void*), void* silexValue943_context);
void silexNative_STD_Threading_native_complete(const SilexNative_STD_Threading_NativeTask* silexValue944);

#ifdef __cplusplus
}
#endif

#endif
