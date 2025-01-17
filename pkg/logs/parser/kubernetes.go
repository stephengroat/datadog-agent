// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package parser

import (
	"bytes"
	"errors"

	"github.com/DataDog/datadog-agent/pkg/logs/message"
)

// KubernetesFormat parses Kubernetes-formatted log lines.  Kubernetes log
// lines follow the pattern '<timestamp> <stream> <flag> <content>'; see
// https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/kuberuntime/logs/logs.go.
// For example: `2018-09-20T11:54:11.753589172Z stdout F This is my message`
var KubernetesFormat Parser = &kubernetesFormat{}

type kubernetesFormat struct{}

// Parse implements Parser#Parse
func (p *kubernetesFormat) Parse(msg []byte) ([]byte, string, string, bool, error) {
	content, status, timestamp, flag, err := parseKubernetes(msg)
	return content, status, timestamp, isPartial(flag), err
}

// SupportsPartialLine implements Parser#SupportsPartialLine
func (p *kubernetesFormat) SupportsPartialLine() bool {
	return true
}

func parseKubernetes(msg []byte) ([]byte, string, string, string, error) {
	var status = message.StatusInfo
	var flag string
	var timestamp string
	// split '<timestamp> <stream> <flag> <content>' into its components
	components := bytes.SplitN(msg, spaceByte, 4)
	if len(components) < 3 {
		return msg, status, timestamp, flag, errors.New("cannot parse the log line")
	}
	var content []byte
	if len(components) > 3 {
		content = components[3]
	}
	status = getStatus(components[1])
	timestamp = string(components[0])
	flag = string(components[2])
	return content, status, timestamp, flag, nil
}

func isPartial(flag string) bool {
	return flag == "P"
}

// getStatus returns the status of the message based on
// the value of the STREAM_TYPE field in the header,
// returns the status INFO by default
func getStatus(streamType []byte) string {
	switch string(streamType) {
	case stdout:
		return message.StatusInfo
	case stderr:
		return message.StatusError
	default:
		return message.StatusInfo
	}
}
