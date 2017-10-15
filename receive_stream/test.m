
clear
load('dataimg.mat');
data = a;
YUV2RGB;
% for i = 1 : 8
%    for j = 1 : 80
%        data(j, i) = a((i - 1)*j + j);
%     end
% end

 for i = 1 : 8
   for j = 1 : 80
       data1(i, j) = Y((i - 1)*j + j);
    end
end
imshow(data1);