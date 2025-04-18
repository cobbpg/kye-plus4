.function ArgHigh(arg) {
	.var type = arg.getType()
	.return CmdArgument(type, type == AT_IMMEDIATE ? >arg.getValue() : arg.getValue() + 1)
}

.pseudocommand movb src : dst {
		lda src
		sta dst
}

.pseudocommand movw src : dst {
		lda src
		sta dst
		lda ArgHigh(src)
		sta ArgHigh(dst)
}

.pseudocommand addw src : dst {
		clc
		lda dst
		adc src
		sta dst
		lda ArgHigh(dst)
		adc ArgHigh(src)
		sta ArgHigh(dst)
}