j = 1;

for i = 1 : 2 : 8*160
	Y(j)= data(i);
    j = j + 1;
% 	Cb = data(i + 1);
% 	Y1 = data(i + 2);
% 	Cr = data(i + 3);
% 	
% 	R = Y0 + 1.371*(Cr-128);
% 	G = Y0 - 0.698*(Cr-128)+0.336*(Cb-128);
% 	B = Y0 + 1.732*(Cb-128);
% 	
% 	R1 = Y1 + 1.371*(Cr-128);
% 	G1 = Y1 - 0.698*(Cr-128)+0.336*(Cb-128);
% 	B1 = Y1 + 1.732*(Cb-128);
% 	
% 	data_endR(j) = R;
% 	data_endG(j) = G;
% 	data_endB(j) = B;	
% 	
% 	j = j + 1;
% 	data_endR(j) = R1;
% 	data_endG(j) = G1;
% 	data_endB(j) = B1;
% 	j = j + 1;
end

% data_end = zeros(8, 80, 3);
% 
% data_end(:,:,1) = data_endR;
% data_end(:,:,2) = data_endG;
% data_end(:,:,3) = data_endB;



