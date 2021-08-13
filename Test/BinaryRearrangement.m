

#import "BinaryRearrangement.h"
#import <dlfcn.h>
#import <libkern/OSAtomic.h>

@implementation BinaryRearrangement

void __sanitizer_cov_trace_pc_guard_init(uint32_t *start, uint32_t *stop) {
    static uint64_t N;  // Counter for the guards.
    if (start == stop || *start) return;  // Initialize only once.
    printf("INIT: %p %p\n", start, stop);
    for (uint32_t *x = start; x < stop; x++)
        *x = ++N;  // Guards should start from 1.
}

// 初始化院子队列
static OSQueueHead list = OS_ATOMIC_QUEUE_INIT;
// 定义节点结构体
typedef struct {
    void *pc; // 存下获取到的PC
    void *next; // 指向下一个节点
} Node;

void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
    // if (!*guard) return;
    void *PC = __builtin_return_address(0);
    
    Node *node = malloc(sizeof(Node));
    *node = (Node){PC, NULL};
    //offsetOf()计算出列尾  OSAtomicEnqueue()把node加入list尾巴
    OSAtomicEnqueue(&list, node, offsetof(Node, next));
}

-(void)printOrderFilePath {
    NSMutableArray *arr = [NSMutableArray array];
    while (1) {
        Node *node = OSAtomicDequeue(&list, offsetof(Node, next));
        if (node == NULL) { // 退出机制
            break;
        }
        // 获取函数信息
        Dl_info info;
        dladdr(node->pc, &info);
        NSString *sname = [NSString stringWithCString:info.dli_sname encoding:NSUTF8StringEncoding];
        
        // 处理c函数以及block前缀
        BOOL isObjc = [sname hasPrefix:@"+["] || [sname hasPrefix:@"-["];
        // c函数及block需要在开头添加下划线
        sname = isObjc ? sname : [@"_" stringByAppendingString:sname];
        
        // 去重复
        if (![arr containsObject:sname] && ![sname containsString:NSStringFromClass([self class])]) {
            // 入栈
            [arr insertObject:sname atIndex:0];
        }
        // 打印看看
        // printf("%s \n", info.dli_sname);
    }
    // 去掉touchBegan方法(因为启动时，不会调用它)
    [arr removeObject:[NSString stringWithFormat:@"%s", __FUNCTION__]];
    // 将数组合成字符串
    NSString *funcStr = [arr componentsJoinedByString:@"\n"];
    // 写入文件
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"link.order"];
    NSLog(@"path: %@", filePath);
    NSData *fileContents = [funcStr dataUsingEncoding:NSUTF8StringEncoding];
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:fileContents attributes:nil];
}

@end
