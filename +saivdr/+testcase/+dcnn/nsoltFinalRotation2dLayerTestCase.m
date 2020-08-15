classdef nsoltFinalRotation2dLayerTestCase < matlab.unittest.TestCase
    %NSOLTFINALROTATION2DLAYERTESTCASE 
    %
    %   コンポーネント別に入力(nComponents):
    %      nRows x nCols x nChs x nSamples
    %
    %   コンポーネント別に出力(nComponents):
    %      nRows x nCols x nDecs x nSamples
    %
    % Requirements: MATLAB R2020a
    %
    % Copyright (c) 2020, Shogo MURAMATSU
    %
    % All rights reserved.
    %
    % Contact address: Shogo MURAMATSU,
    %                Faculty of Engineering, Niigata University,
    %                8050 2-no-cho Ikarashi, Nishi-ku,
    %                Niigata, 950-2181, JAPAN
    %
    % http://msiplab.eng.niigata-u.ac.jp/ 
    
    properties (TestParameter)
        nchs = { [3 3], [4 4] };
        stride = { [2 2] };
        mus = { -1, 1 };
        datatype = { 'single', 'double' };
        nrows = struct('small', 4,'medium', 8, 'large', 16);
        ncols = struct('small', 4,'medium', 8, 'large', 16);
    end
    
    methods (TestClassTeardown)
        function finalCheck(~)
            import saivdr.dcnn.*
            layer = nsoltFinalRotation2dLayer(...
                'NumberOfChannels',[3 3],...
                'DecimationFactor',[2 2]);
            fprintf("\n --- Check layer for 2-D images ---\n");
            checkLayer(layer,[8 8 6],'ObservationDimension',4)
        end
    end
    
    methods (Test)
        
        function testConstructor(testCase, nchs, stride)
            
            % Expected values
            expctdName = 'V0~';
            expctdDescription = "NSOLT final rotation " ...
                + "(ps,pa) = (" ...
                + nchs(1) + "," + nchs(2) + "), "  ...
                + "(mv,mh) = (" ...
                + stride(1) + "," + stride(2) + ")";
            
            % Instantiation of target class
            import saivdr.dcnn.*
            layer = nsoltFinalRotation2dLayer(...
                'NumberOfChannels',nchs,...
                'DecimationFactor',stride,...
                'Name',expctdName);
            
            % Actual values
            actualName = layer.Name;
            actualDescription = layer.Description;
            
            % Evaluation
            testCase.verifyEqual(actualName,expctdName);
            testCase.verifyEqual(actualDescription,expctdDescription);
        end

        function testPredictGrayscale(testCase, ...
                nchs, stride, nrows, ncols, datatype)
            
            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.AbsoluteTolerance
            tolObj = AbsoluteTolerance(1e-6,single(1e-6));
            
            % Parameters
            nSamples = 8;
            nDecs = prod(stride);
            % nRows x nCols x nChs x nSamples
            X = randn(nrows,ncols,sum(nchs),nSamples,datatype);
            % Expected values        
            % nRows x nCols x nDecs x nSamples
            ps = nchs(1);
            pa = nchs(2);
            W0T = eye(ps,datatype);
            U0T = eye(pa,datatype);
            Y = permute(X,[3 1 2 4]);
            Ys = reshape(Y(1:ps,:,:,:),ps,nrows*ncols*nSamples);
            Ya = reshape(Y(ps+1:ps+pa,:,:,:),pa,nrows*ncols*nSamples);
            Zsa = [ W0T(1:nDecs/2,:)*Ys; U0T(1:nDecs/2,:)*Ya ];
            expctdZ = ipermute(reshape(Zsa,nDecs,nrows,ncols,nSamples),...
                [3 1 2 4]);
            
            % Instantiation of target class
            import saivdr.dcnn.*
            layer = nsoltFinalRotation2dLayer(...
                'NumberOfChannels',nchs,...
                'DecimationFactor',stride,...
                'Name','V0~');
            
            % Actual values
            actualZ = layer.predict(X);
            
            % Evaluation
            testCase.verifyInstanceOf(actualZ,datatype);
            testCase.verifyThat(actualZ,...
                IsEqualTo(expctdZ,'Within',tolObj));
            
        end
        
        function testPredictGrayscaleWithRandomAngles(testCase, ...
                nchs, stride, nrows, ncols, datatype)
            
            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.AbsoluteTolerance
            tolObj = AbsoluteTolerance(1e-6,single(1e-6));
            import saivdr.dictionary.utility.*
            genW = OrthonormalMatrixGenerationSystem();
            genU = OrthonormalMatrixGenerationSystem();
            
            % Parameters
            nSamples = 8;
            nDecs = prod(stride);
            nChsTotal = sum(nchs);
            % nRows x nCols x nChs x nSamples
            X = randn(nrows,ncols,sum(nchs),nSamples,datatype);
            angles = randn((nChsTotal-2)*nChsTotal/4,1);
            
            % Expected values
            % nRows x nCols x nDecs x nSamples
            ps = nchs(1);
            pa = nchs(2);
            W0T = transpose(genW.step(angles(1:length(angles)/2),1));
            U0T = transpose(genU.step(angles(length(angles)/2+1:end),1));
            Y = permute(X,[3 1 2 4]);
            Ys = reshape(Y(1:ps,:,:,:),ps,nrows*ncols*nSamples);
            Ya = reshape(Y(ps+1:ps+pa,:,:,:),pa,nrows*ncols*nSamples);
            Zsa = [ W0T(1:nDecs/2,:)*Ys; U0T(1:nDecs/2,:)*Ya ];
            expctdZ = ipermute(reshape(Zsa,nDecs,nrows,ncols,nSamples),...
                [3 1 2 4]);
            
            % Instantiation of target class
            import saivdr.dcnn.*
            layer = nsoltFinalRotation2dLayer(...
                'NumberOfChannels',nchs,...
                'DecimationFactor',stride,...
                'Name','V0~');
            
            % Actual values
            layer.Angles = angles;
            actualZ = layer.predict(X);
            
            % Evaluation
            testCase.verifyInstanceOf(actualZ,datatype);
            testCase.verifyThat(actualZ,...
                IsEqualTo(expctdZ,'Within',tolObj));
            
        end
        
        function testPredictGrayscaleWithRandomAnglesNoDcLeackage(testCase, ...
                nchs, stride, nrows, ncols, mus, datatype)
            
            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.AbsoluteTolerance
            tolObj = AbsoluteTolerance(1e-6,single(1e-6));
            import saivdr.dictionary.utility.*
            genW = OrthonormalMatrixGenerationSystem();
            genU = OrthonormalMatrixGenerationSystem();
            
            % Parameters
            nSamples = 8;
            nDecs = prod(stride);
            nChsTotal = sum(nchs);
            % nRows x nCols x nChs x nSamples
            X = randn(nrows,ncols,sum(nchs),nSamples,datatype);
            angles = randn((nChsTotal-2)*nChsTotal/4,1);
            
            % Expected values
            % nRows x nCols x nDecs x nSamples
            ps = nchs(1);
            pa = nchs(2);
            anglesNoDc = angles;
            anglesNoDc(1:ps-1,1)=zeros(ps-1,1);
            musW = mus*ones(ps,1);
            musW(1,1) = 1;
            musU = mus*ones(pa,1);
            W0T = transpose(genW.step(anglesNoDc(1:length(angles)/2),musW));
            U0T = transpose(genU.step(anglesNoDc(length(angles)/2+1:end),musU));
            Y = permute(X,[3 1 2 4]);
            Ys = reshape(Y(1:ps,:,:,:),ps,nrows*ncols*nSamples);
            Ya = reshape(Y(ps+1:ps+pa,:,:,:),pa,nrows*ncols*nSamples);
            Zsa = [ W0T(1:nDecs/2,:)*Ys; U0T(1:nDecs/2,:)*Ya ];
            expctdZ = ipermute(reshape(Zsa,nDecs,nrows,ncols,nSamples),...
                [3 1 2 4]);
            
            % Instantiation of target class
            import saivdr.dcnn.*
            layer = nsoltFinalRotation2dLayer(...
                'NumberOfChannels',nchs,...
                'DecimationFactor',stride,...
                'NoDcLeakage',true,...
                'Name','V0~');
            
            % Actual values
            layer.Mus = mus;
            layer.Angles = angles;
            actualZ = layer.predict(X);
            
            % Evaluation
            testCase.verifyInstanceOf(actualZ,datatype);
            testCase.verifyThat(actualZ,...
                IsEqualTo(expctdZ,'Within',tolObj));
            
        end
        
        function testForwardBackwardGrayscale(testCase, ...
                nchs, stride, nrows, ncols, datatype)
            
            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.AbsoluteTolerance
            tolObj = AbsoluteTolerance(1e-4,single(1e-4));
            import saivdr.dictionary.utility.*
            genW = OrthonormalMatrixGenerationSystem(...
                'PartialDifference','on');
            genU = OrthonormalMatrixGenerationSystem(...
                'PartialDifference','on');            
            
            % Parameters
            nSamples = 8;
            nDecs = prod(stride);
            nChsTotal = sum(nchs);
            nAnglesH = (nChsTotal-2)*nChsTotal/8;
            anglesW = zeros(nAnglesH,1,datatype);            
            anglesU = zeros(nAnglesH,1,datatype);  
            mus_ = 1;
            
            % nRows x nCols x nDecs x nSamples            
            X = randn(nrows,ncols,sum(nchs),nSamples,datatype);            
            dLdZ = randn(nrows,ncols,nDecs,nSamples,datatype);
            
            % Expected values
            expctdMem = X;
            % nRows x nCols x nChs x nSamples
            ps = nchs(1);
            pa = nchs(2);
            
            % dLdX = dZdX x dLdZ
            W0 = genW.step(anglesW,mus_,0);
            U0 = genU.step(anglesU,mus_,0);
            expctddLdX = zeros(nrows,ncols,nChsTotal,nSamples,datatype);
            Y  = zeros(nChsTotal,nrows,ncols,datatype);
            for iSample=1:nSamples
                % Perumation in each block                
                Ai = permute(dLdZ(:,:,:,iSample),[3 1 2]); 
                Yi = reshape(Ai,nDecs,nrows,ncols);
                %
                Ys = Yi(1:nDecs/2,:);
                Ya = Yi(nDecs/2+1:end,:);
                Y(1:ps,:,:) = ...
                    reshape(W0(:,1:nDecs/2)*Ys,ps,nrows,ncols);
                Y(ps+1:ps+pa,:,:) = ...
                    reshape(U0(:,1:nDecs/2)*Ya,pa,nrows,ncols);
                expctddLdX(:,:,:,iSample) = ipermute(Y,[3 1 2]);                
            end
            
            % dLdWi = <dLdZ,(dVdWi)X>
            expctddLdW = zeros(2*nAnglesH,1,datatype);
            dldz_ = permute(dLdZ,[3 1 2 4]);
            dldz_upp = reshape(dldz_(1:nDecs/2,:,:,:),nDecs/2,nrows*ncols*nSamples);
            dldz_low = reshape(dldz_(nDecs/2+1:nDecs,:,:,:),nDecs/2,nrows*ncols*nSamples);
            % (dVdWi)X
            for iAngle = 1:nAnglesH
                dW0_T = transpose(genW.step(anglesW,mus_,iAngle));
                dU0_T = transpose(genU.step(anglesU,mus_,iAngle));
                a_ = permute(X,[3 1 2 4]);
                c_upp = reshape(a_(1:ps,:,:,:),ps,nrows*ncols*nSamples);                
                c_low = reshape(a_(ps+1:ps+pa,:,:,:),pa,nrows*ncols*nSamples);
                d_upp = dW0_T(1:nDecs/2,:)*c_upp;
                d_low = dU0_T(1:nDecs/2,:)*c_low;
                expctddLdW(iAngle) = sum(dldz_upp.*d_upp,'all');
                expctddLdW(nAnglesH+iAngle) = sum(dldz_low.*d_low,'all');
            end
            
            % Instantiation of target class
            import saivdr.dcnn.*
            layer = nsoltFinalRotation2dLayer(...
                'NumberOfChannels',nchs,...
                'DecimationFactor',stride,...
                'Name','V0~');
            layer.Mus = mus_;
            expctdZ = layer.predict(X);
            
            % Actual values
            [actualZ,actualMem] = layer.forward(X);
            [actualdLdX,actualdLdW] = layer.backward([],[],dLdZ,actualMem);
            
            % Evaluation
            testCase.verifyInstanceOf(actualMem,datatype);            
            testCase.verifyInstanceOf(actualZ,datatype);                        
            testCase.verifyInstanceOf(actualdLdX,datatype);
            testCase.verifyInstanceOf(actualdLdW,datatype);            
            testCase.verifyThat(actualMem,...
                IsEqualTo(expctdMem,'Within',tolObj));
            testCase.verifyThat(actualZ,...
                IsEqualTo(expctdZ,'Within',tolObj));
            testCase.verifyThat(actualdLdX,...
                IsEqualTo(expctddLdX,'Within',tolObj));            
            testCase.verifyThat(actualdLdW,...
                IsEqualTo(expctddLdW,'Within',tolObj));  
            
        end
        
        function testForwardBackwardGayscaleWithRandomAngles(testCase, ...
                nchs, stride, nrows, ncols, datatype)
            
            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.AbsoluteTolerance
            tolObj = AbsoluteTolerance(1e-4,single(1e-4));
            import saivdr.dictionary.utility.*
            genW = OrthonormalMatrixGenerationSystem(...
                'PartialDifference','on');
            genU = OrthonormalMatrixGenerationSystem(...
                'PartialDifference','on');
            
            % Parameters
            nSamples = 8;
            nDecs = prod(stride);
            nChsTotal = sum(nchs);
            nAnglesH = (nChsTotal-2)*nChsTotal/8;
            anglesW = randn(nAnglesH,1);
            anglesU = randn(nAnglesH,1);
            mus_ = 1;
            
            % nRows x nCols x nDecs x nSamples
            X = randn(nrows,ncols,sum(nchs),nSamples,datatype);
            dLdZ = randn(nrows,ncols,nDecs,nSamples,datatype);
            
            % Expected values
            expctdMem = X;
            % nRows x nCols x nChs x nSamples
            ps = nchs(1);
            pa = nchs(2);
            
            % dLdX = dZdX x dLdZ
            W0 = genW.step(anglesW,mus_,0);
            U0 = genU.step(anglesU,mus_,0);
            expctddLdX = zeros(nrows,ncols,nChsTotal,nSamples,datatype);
            Y  = zeros(nChsTotal,nrows,ncols,datatype);
            for iSample=1:nSamples
                % Perumation in each block
                Ai = permute(dLdZ(:,:,:,iSample),[3 1 2]);
                Yi = reshape(Ai,nDecs,nrows,ncols);
                %
                Ys = Yi(1:nDecs/2,:);
                Ya = Yi(nDecs/2+1:end,:);
                Y(1:ps,:,:) = ...
                    reshape(W0(:,1:nDecs/2)*Ys,ps,nrows,ncols);
                Y(ps+1:ps+pa,:,:) = ...
                    reshape(U0(:,1:nDecs/2)*Ya,pa,nrows,ncols);
                expctddLdX(:,:,:,iSample) = ipermute(Y,[3 1 2]);
            end
            
            % dLdWi = <dLdZ,(dVdWi)X>
            expctddLdW = zeros(2*nAnglesH,1,datatype);
            dldz_ = permute(dLdZ,[3 1 2 4]);
            dldz_upp = reshape(dldz_(1:nDecs/2,:,:,:),nDecs/2,nrows*ncols*nSamples);
            dldz_low = reshape(dldz_(nDecs/2+1:nDecs,:,:,:),nDecs/2,nrows*ncols*nSamples);
            % (dVdWi)X
            for iAngle = 1:nAnglesH
                dW0_T = transpose(genW.step(anglesW,mus_,iAngle));
                dU0_T = transpose(genU.step(anglesU,mus_,iAngle));
                a_ = permute(X,[3 1 2 4]);
                c_upp = reshape(a_(1:ps,:,:,:),ps,nrows*ncols*nSamples);
                c_low = reshape(a_(ps+1:ps+pa,:,:,:),pa,nrows*ncols*nSamples);
                d_upp = dW0_T(1:nDecs/2,:)*c_upp;
                d_low = dU0_T(1:nDecs/2,:)*c_low;
                expctddLdW(iAngle) = sum(dldz_upp.*d_upp,'all');
                expctddLdW(nAnglesH+iAngle) = sum(dldz_low.*d_low,'all');
            end
            
            % Instantiation of target class
            import saivdr.dcnn.*
            layer = nsoltFinalRotation2dLayer(...
                'NumberOfChannels',nchs,...
                'DecimationFactor',stride,...
                'Name','V0~');
            layer.Mus = mus_;
            layer.Angles = [anglesW; anglesU];
            expctdZ = layer.predict(X);
            
            % Actual values
            [actualZ,actualMem] = layer.forward(X);
            [actualdLdX,actualdLdW] = layer.backward([],[],dLdZ,actualMem);
            
            % Evaluation
            testCase.verifyInstanceOf(actualMem,datatype);
            testCase.verifyInstanceOf(actualZ,datatype);
            testCase.verifyInstanceOf(actualdLdX,datatype);
            testCase.verifyInstanceOf(actualdLdW,datatype);
            testCase.verifyThat(actualMem,...
                IsEqualTo(expctdMem,'Within',tolObj));
            testCase.verifyThat(actualZ,...
                IsEqualTo(expctdZ,'Within',tolObj));
            testCase.verifyThat(actualdLdX,...
                IsEqualTo(expctddLdX,'Within',tolObj));
            testCase.verifyThat(actualdLdW,...
                IsEqualTo(expctddLdW,'Within',tolObj));
            
        end
        
        function testForwardBackwardWithRandomAnglesNoDcLeackage(testCase, ...
                nchs, stride, nrows, ncols, mus, datatype)
            
            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.AbsoluteTolerance
            tolObj = AbsoluteTolerance(1e-4,single(1e-4));
            import saivdr.dictionary.utility.*
            genW = OrthonormalMatrixGenerationSystem(...
                'PartialDifference','on');
            genU = OrthonormalMatrixGenerationSystem(...
                'PartialDifference','on');
            
            % Parameters
            nSamples = 8;
            nDecs = prod(stride);
            nChsTotal = sum(nchs);
            nAnglesH = (nChsTotal-2)*nChsTotal/8;
            anglesW = randn(nAnglesH,1);
            anglesU = randn(nAnglesH,1);
            
            % nRows x nCols x nDecs x nSamples
            X = randn(nrows,ncols,sum(nchs),nSamples,datatype);
            dLdZ = randn(nrows,ncols,nDecs,nSamples,datatype);
            
            % Expected values
            expctdMem = X;
            % nRows x nCols x nChs x nSamples
            ps = nchs(1);
            pa = nchs(2);
            
            % dLdX = dZdX x dLdZ
            anglesW_NoDc = anglesW;
            anglesW_NoDc(1:ps-1,1)=zeros(ps-1,1);
            musW = mus*ones(ps,1);
            musW(1,1) = 1;
            musU = mus*ones(pa,1);
            W0 = genW.step(anglesW_NoDc,musW,0);
            U0 = genU.step(anglesU,musU,0);
            expctddLdX = zeros(nrows,ncols,nChsTotal,nSamples,datatype);
            Y  = zeros(nChsTotal,nrows,ncols,datatype);
            for iSample=1:nSamples
                % Perumation in each block
                Ai = permute(dLdZ(:,:,:,iSample),[3 1 2]);
                Yi = reshape(Ai,nDecs,nrows,ncols);
                %
                Ys = Yi(1:nDecs/2,:);
                Ya = Yi(nDecs/2+1:end,:);
                Y(1:ps,:,:) = ...
                    reshape(W0(:,1:nDecs/2)*Ys,ps,nrows,ncols);
                Y(ps+1:ps+pa,:,:) = ...
                    reshape(U0(:,1:nDecs/2)*Ya,pa,nrows,ncols);
                expctddLdX(:,:,:,iSample) = ipermute(Y,[3 1 2]);
            end
            
            % dLdWi = <dLdZ,(dVdWi)X>
            expctddLdW = zeros(2*nAnglesH,1,datatype);
            dldz_ = permute(dLdZ,[3 1 2 4]);
            dldz_upp = reshape(dldz_(1:nDecs/2,:,:,:),nDecs/2,nrows*ncols*nSamples);
            dldz_low = reshape(dldz_(nDecs/2+1:nDecs,:,:,:),nDecs/2,nrows*ncols*nSamples);
            % (dVdWi)X
            for iAngle = 1:nAnglesH
                dW0_T = transpose(genW.step(anglesW_NoDc,musW,iAngle));
                dU0_T = transpose(genU.step(anglesU,musU,iAngle));
                a_ = permute(X,[3 1 2 4]);
                c_upp = reshape(a_(1:ps,:,:,:),ps,nrows*ncols*nSamples);
                c_low = reshape(a_(ps+1:ps+pa,:,:,:),pa,nrows*ncols*nSamples);
                d_upp = dW0_T(1:nDecs/2,:)*c_upp;
                d_low = dU0_T(1:nDecs/2,:)*c_low;
                expctddLdW(iAngle) = sum(dldz_upp.*d_upp,'all');
                expctddLdW(nAnglesH+iAngle) = sum(dldz_low.*d_low,'all');
            end
            
            % Instantiation of target class
            import saivdr.dcnn.*
            layer = nsoltFinalRotation2dLayer(...
                'NumberOfChannels',nchs,...
                'DecimationFactor',stride,...
                'NoDcLeakage',true,...
                'Name','V0~');
            layer.Mus = mus;
            layer.Angles = [anglesW; anglesU];
            expctdZ = layer.predict(X);
            
            % Actual values
            [actualZ,actualMem] = layer.forward(X);
            [actualdLdX,actualdLdW] = layer.backward([],[],dLdZ,actualMem);
            
            % Evaluation
            testCase.verifyInstanceOf(actualMem,datatype);
            testCase.verifyInstanceOf(actualZ,datatype);
            testCase.verifyInstanceOf(actualdLdX,datatype);
            testCase.verifyInstanceOf(actualdLdW,datatype);
            testCase.verifyThat(actualMem,...
                IsEqualTo(expctdMem,'Within',tolObj));
            testCase.verifyThat(actualZ,...
                IsEqualTo(expctdZ,'Within',tolObj));
            testCase.verifyThat(actualdLdX,...
                IsEqualTo(expctddLdX,'Within',tolObj));
            testCase.verifyThat(actualdLdW,...
                IsEqualTo(expctddLdW,'Within',tolObj));
        end

    end

end

