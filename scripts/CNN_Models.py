import os
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.autograd import Variable
from torch.utils.data import TensorDataset, DataLoader

# Architecture taken from original code here: https://github.com/idiap/CNN_QbE_STD/blob/master/Model_Query_Detection_DTW_CNN.py

class ConvNet(nn.Module):
    def __init__(self, depth = 30, dropout=0.1):
        super(ConvNet, self).__init__()
        self.conv1 = nn.Conv2d(in_channels = 1, out_channels = 30, kernel_size = 3)
        self.conv2 = nn.Conv2d(in_channels = 30, out_channels = 30, kernel_size = 3)
        self.maxpool  = nn.MaxPool2d(kernel_size = 2, stride= 2)

        self.conv4 = nn.Conv2d(in_channels = 30, out_channels = 30, kernel_size = 3)
        self.conv5 = nn.Conv2d(in_channels = 30, out_channels = 30, kernel_size = 3)
        # 6 = maxpool

        self.conv7 = nn.Conv2d(in_channels = 30, out_channels = 30, kernel_size = 3)
        self.conv8 = nn.Conv2d(in_channels = 30, out_channels = 30, kernel_size = 3)
        # 9 = maxpool

        self.conv10 = nn.Conv2d(in_channels = 30, out_channels = 30, kernel_size = 3)
        self.conv11 = nn.Conv2d(in_channels = 30, out_channels = int(depth/2), kernel_size = 1)
        # 12 = maxpool (output size = M x depth/2 x 3 x 47)

        self.length = int((depth/2) * 3 * 47)
        self.fc1 = nn.Linear(self.length, 60)
        self.fc2 = nn.Linear(60, 1)

        self.dout_layer = nn.Dropout(dropout)

    def forward(self, x):
        x = F.relu(self.dout_layer(self.conv1(x)))
        x = F.relu(self.dout_layer(self.conv2(x)))
        x = self.maxpool(x)
        
        x = F.relu(self.dout_layer(self.conv4(x)))
        x = F.relu(self.dout_layer(self.conv5(x)))
        x = self.maxpool(x)

        x = F.relu(self.dout_layer(self.conv7(x)))
        x = F.relu(self.dout_layer(self.conv8(x)))
        x = self.maxpool(x)

        x = F.relu(self.dout_layer(self.conv10(x)))
        x = F.relu(self.dout_layer(self.conv11(x)))
        x = self.maxpool(x)

        x = x.view(-1, self.length)
        x = F.relu(self.dout_layer(self.fc1(x)))
        x = self.fc2(x)
        x = torch.sigmoid(x)

        return x

# VGG code adapted from: https://github.com/MLSpeech/speech_yolo/blob/master/model_speech_yolo.py

class VGG(nn.Module):
    def __init__(self, vgg_name):
        cfg = {
            'VGG11': [64, 'M', 128, 'M', 256, 256, 'M', 512, 512, 'M', 512, 512, 'M'],
            'VGG13': [64, 64, 'M', 128, 128, 'M', 256, 256, 'M', 512, 512, 'M', 512, 512, 'M'],
            'VGG16': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 'M', 512, 512, 512, 'M', 512, 512, 512, 'M'],
            'VGG19': [64, 64, 'M', 128, 128, 'M', 256, 256, 256, 256, 'M', 512, 512, 512, 512, 'M', 512, 512, 512, 512, 'M'],
        }

        def _make_layers(cfg, kernel=3):
            layers = []
            in_channels = 1
            for x in cfg:
                if x == 'M':
                    layers += [nn.MaxPool2d(kernel_size=2, stride=2)]
                else:
                    layers += [nn.Conv2d(in_channels, x, kernel_size=kernel, padding=1),
                                nn.BatchNorm2d(x),
                                nn.ReLU(inplace=True),
                                nn.Dropout(p = 0.1)]
                    in_channels = x
            layers += [nn.AvgPool2d(kernel_size=1, stride=1)]
            return nn.Sequential(*layers)

        super(VGG, self).__init__()
        self.features = _make_layers(cfg[vgg_name])
        self.fc1 = nn.Linear(38400, 512)
        self.fc2 = nn.Linear(512, 1)
        self.dout_layer = nn.Dropout(0.1)

    def forward(self, x):
        # out = self.features(x)
        for m in self.features.children():
            # x_in = x.shape
            x = m(x)
            # print("%s -> %s" % (x_in, x.shape))

        out = x
        out = out.view(out.size(0), -1)
        out = self.dout_layer(self.fc1(out))
        out = self.fc2(out)
        return torch.sigmoid(out)

class VGG11(VGG):
    def __init__(self):
        VGG.__init__(self, 'VGG11')

conv_block = nn.Sequential(nn.Conv2d(3,64,kernel_size=7, stride=2, padding=3, bias=False), #112,112
                            nn.BatchNorm2d(64),
                            nn.ReLU(inplace=True),
                            nn.MaxPool2d(kernel_size=3, stride=2, padding=1)) # 56,56

# ResNet code adapted from: https://github.com/pytorch/vision/blob/master/torchvision/models/resnet.py

class BasicBlock(nn.Module):
    def __init__(self, inplanes, planes, stride=1, downsample=None):
        super().__init__()
        self.conv1 = nn.Conv2d(inplanes, planes, kernel_size=3, stride=stride, padding=1, bias=False)
        self.bn1 = nn.BatchNorm2d(planes)
        self.relu = nn.ReLU(inplace=True)
        self.conv2 = nn.Conv2d(planes, planes, kernel_size=3, stride=1, padding=1, bias=False)
        self.bn2 = nn.BatchNorm2d(planes)
        self.downsample = downsample
        self.stride = stride

    def forward(self, x):
        identity = x

        out = self.conv1(x)
        out = self.bn1(out)
        out = self.relu(out)

        out = self.conv2(out)
        out = self.bn2(out)

        if self.downsample is not None:
            identity = self.downsample(x)

        out += identity
        out = self.relu(out)

        return out

class ResNet(nn.Module):

    def __init__(self, block, layers, num_classes=1):
        super().__init__()
        
        self.inplanes = 64

        self.conv1 = nn.Conv2d(in_channels = 1, out_channels = self.inplanes, kernel_size=7, stride=2, padding=3, bias=False)
        self.bn1 = nn.BatchNorm2d(self.inplanes)
        self.relu = nn.ReLU(inplace=True)
        self.maxpool = nn.MaxPool2d(kernel_size=3, stride=2, padding=1)
        
        self.layer1 = self._make_layer(block, 64, layers[0])
        self.layer2 = self._make_layer(block, 128, layers[1], stride=2)
        self.layer3 = self._make_layer(block, 256, layers[2], stride=2)
        self.layer4 = self._make_layer(block, 512, layers[3], stride=2)
        
        self.avgpool = nn.AdaptiveAvgPool2d((1, 1))
        self.fc = nn.Linear(512 , num_classes)


    def _make_layer(self, block, planes, blocks, stride=1):
        downsample = None  

        if stride != 1 or self.inplanes != planes:
            downsample = nn.Sequential(
                nn.Conv2d(self.inplanes, planes, 1, stride, bias=False),
                nn.BatchNorm2d(planes),
            )

        layers = []
        layers.append(block(self.inplanes, planes, stride, downsample))
        
        self.inplanes = planes
        
        for _ in range(1, blocks):
            layers.append(block(self.inplanes, planes))

        return nn.Sequential(*layers)
    
    
    def forward(self, x):
        x = self.conv1(x)
        x = self.bn1(x)
        x = self.relu(x)
        x = self.maxpool(x)

        x = self.layer1(x)
        x = self.layer2(x)
        x = self.layer3(x)
        x = self.layer4(x)

        x = self.avgpool(x)
        x = torch.flatten(x, 1)
        x = self.fc(x)

        return torch.sigmoid(x)

class ResNet34(ResNet):
    def __init__(self):
        layers=[3, 4, 6, 3]
        ResNet.__init__(self, BasicBlock, layers)
