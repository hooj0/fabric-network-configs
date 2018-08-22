#!/bin/sh

function log() {
	# 字颜色：30—–37
	# 字背景颜色范围：40—–47
	case "$1" in
		"red")
			echo -e "\033[31m$2\033[0m" # 红色字
		;; 
		"yellow")
			echo -e "\033[33m$2\033[0m" # 黄色字
		;; 
		"green")
			echo -e "\033[32m$2\033[0m" # 绿色字
		;; 
		"blue")
			echo -e "\033[34m$2\033[0m" # 蓝色字
		;; 
		"purple")
			echo -e "\033[35m$2\033[0m" # 紫色字
		;; 
		"sky_blue")
			echo -e "\033[36m$2\033[0m" # 天蓝字
		;; 
		"white")
			echo -e "\033[37m$2\033[0m" # 白色字
		;; 
		"_black")
			echo -e "\033[40;37m $2 \033[0m" # 黑底白字
		;; 
		"_red")
			echo -e "\033[41;30m $2 \033[0m" # 红底黑字
		;; 
		*)
			echo "$2"
		;;
	esac
}
