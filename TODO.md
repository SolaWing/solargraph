* [x] define_method self的推断
* struct的支持
* 类型标注: {String => <String>} 的补全的解析
* 换行时的补全不能即时解析出来
* 性能优化
    * 限制频率, 目前没有限流，导致会不断的计算堆积
    * 优化关键函数
    * 相应测试
* callHierachy
* Typecheck
    * Hash#[key] 报参数多了.. 仅自己的工程出现问题
    * Net::HTTP.new 识别不了，net/http require不了(可能和rbs有关？)
    * Array#first, Object#then 等等的泛型推断错误
