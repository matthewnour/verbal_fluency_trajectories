function [vector_of_items iterations communityAssignment, fullUnfoldingCommAllocation, finalModularity] = consensus_clustering_louvain_lex(inputMatrix, numberPartitions, consensusMatrixThreshold, LouvainMethod, gamma)
% Function to implement consensus clustering as per Lancichinetti & Forunato et al 2012 using the Louvain algorithm as implemented by BCT
%
% Inputs:
%   inputMatrix                 symmetrical weighted undirected adjacency matrix to be partiitioned
%   numberIterations            number of times the algorithm is run to  generate the consensus matrix on each run
%   consensusMatrixThreshold    threshold below which consensus matrix  entries are set to zero, (0 1]
%   LouvainMethod               string of Louvain method: 'Modularity' (if no negative weights in the inputMatrix, or 'negative_sym' / 'negative_asym' if negative weights)
%   gamma                       resolution parameter of Louvain
%
% Outputs:
%   finalPartition              final community allocaiton of each node
%   iterations                  how many iterations to reach consensus
%   communityAssignment         final community assignment
%   fullUnfoldingCommAllocation the node->community assignment of each iteration on the trajectory to the final allocation
%
% Matthew Nour, London, May 2018


D = zeros(size(inputMatrix,1), size(inputMatrix,2), numberPartitions);  %consensus matrix
consensus = 0;
iterations= 0;
vector_of_items = zeros(size(inputMatrix,1),1);

while consensus==0 
    
    iterations = iterations + 1; % keep track
     
    % generate consensus matrix
    for partition = 1:numberPartitions
        clear community_allocation
   
        [community_allocation, Q] = community_louvain_lex(inputMatrix, gamma, [], LouvainMethod);
        final_iteration = length(community_allocation); % when we save every iteration

        for row = 1:size(D,1)
            for col = 1:size(D,2)
                D(row, col, partition) = community_allocation{final_iteration}(row) == community_allocation{final_iteration}(col);
            end
        end
        
    end % end generation of partitions on this run
    
    D = mean(D,3);  %consensus matrix...is it equal or do we need to keep going?
    
    if length(unique(D))<3 && iterations>=2 
        % only true if all the parition matrices are equal (so that their mean is either 0 or 1);
        % and have had at least 1 round of clustering on the consensus matrix
        
        consensus = 1;
        
        finalPartition = D;
        finalModularity = Q;
        
        for community = 1:length(unique(community_allocation{final_iteration}));
            items_in_this_community = find((community_allocation{final_iteration})==community);
            communityAssignment{community} = items_in_this_community;
            vector_of_items(items_in_this_community) = community;
        end
        
    else
        
        % consensus thresholding
        D(D<consensusMatrixThreshold)=0;
        inputMatrix = D;
        
    end  % end check if final partition reached
    
end    %end while loop (keeps going until consesnus reached

fullUnfoldingCommAllocation = community_allocation;

end    % end function

