# CA_LAB

exp22：

定位到在exp19中添加tlb异常后，未更改宏导致EXE_res_from_csr、MEM_res_from_csr取到错误的异常种类。自本次exp开始，data conflict的判定集成在ID.v内，原有的DATAHAZR.v相关信号悬空，但不再删除以防引入其他潜在错误。

