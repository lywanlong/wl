# 类库的使用
- 类库用的script\y3\tools\class.lua
- 创建一个类 local M = Class 'ClassName'
- 构造函数 function M:__init()
- 析构函数 function M:__del() 但是需要用Extends ("ClassName", "GCHost") 去扩展GCHost才可以使用
- 创建一个实例 local instance = New 'ClassName' ()

# strp库要求

