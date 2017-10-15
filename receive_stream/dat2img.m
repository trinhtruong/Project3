clear
clc
figure
fileID = fopen('log.dat'); 
OneByte = fread(fileID,'*ubit8');
A = OneByte';
for i = 1:80
    for j = 1:60
        B(j,i) = A(j*i);
end
end
imshow(B)